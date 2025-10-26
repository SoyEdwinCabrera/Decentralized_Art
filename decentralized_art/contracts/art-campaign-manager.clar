;; -------------------------------------------------------------
;; CONTRACT: artwork-campaign.clar
;; Decentralized_Art - Mecanazgo y sorteos justos
;; -------------------------------------------------------------

(define-constant PLATFORM_FEE_PERCENT u10)
(define-constant PLATFORM_WALLET 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

(define-data-var campaign-counter uint u0)

;; Registro de campanas
(define-map campaigns
    { id: uint }
    {
        artist: principal,
        goal: uint,
        raised: uint,
        ticket-price: uint,
        deadline: uint,
        active: bool,
        donor-count: uint,
        winner: (optional principal),
        ipfs-hash: (optional (string-ascii 256)),
    }
)

;; Lista de donantes por campana
(define-map campaign-donors
    {
        campaign-id: uint,
        index: uint,
    }
    principal
)

;; Donaciones
(define-map donations
    {
        campaign-id: uint,
        donor: principal,
    }
    { amount: uint }
)

;; Crear una nueva campana
(define-public (create-campaign
        (goal uint)
        (ticket-price uint)
        (deadline uint)
        (ipfs-hash (string-ascii 256))
    )
    (let ((current (var-get campaign-counter)))
        (begin
            (var-set campaign-counter (+ current u1))
            (let (
                    (new-id (+ current u1))
                    (ipfs-opt (if (is-eq ipfs-hash "")
                        none
                        (some ipfs-hash)
                    ))
                )
                (map-set campaigns { id: new-id } {
                    artist: tx-sender,
                    goal: goal,
                    raised: u0,
                    ticket-price: ticket-price,
                    deadline: deadline,
                    active: true,
                    donor-count: u0,
                    ipfs-hash: ipfs-opt,
                    winner: none,
                })
                (ok {
                    id: new-id,
                    msg: "Campaign created!",
                    ticket: ticket-price,
                })
            )
        )
    )
)

;; Donar STX (debe ser igual al precio del ticket)
(define-public (donate
        (campaign-id uint)
        (amount uint)
    )
    (let ((campaign-opt (map-get? campaigns { id: campaign-id })))
        (match campaign-opt
            campaign-data (if (get active campaign-data)
                (let (
                        (count (get donor-count campaign-data))
                        (ticket (get ticket-price campaign-data))
                    )
                    (begin
                        (asserts! (is-eq amount ticket)
                            (err "Monto debe ser igual al ticket")
                        )
                        (asserts! (< count u100)
                            (err "Maximo de donantes alcanzado")
                        )
                        ;; transferir STX al contrato
                        (unwrap!
                            (stx-transfer? amount tx-sender
                                (as-contract tx-sender)
                            )
                            (err "Transferencia fallida")
                        )
                        ;; registrar donacion
                        (map-set donations {
                            campaign-id: campaign-id,
                            donor: tx-sender,
                        } { amount: amount }
                        )
                        (map-set campaign-donors {
                            campaign-id: campaign-id,
                            index: count,
                        }
                            tx-sender
                        )
                        (map-set campaigns { id: campaign-id }
                            (merge campaign-data {
                                raised: (+ (get raised campaign-data) amount),
                                donor-count: (+ count u1),
                            })
                        )
                        (ok true)
                    )
                )
                (err "Campania no activa")
            )
            (err "Campania no encontrada")
        )
    )
)

;; Cerrar campana y seleccionar ganador
(define-public (close-campaign
        (campaign-id uint)
        (seed uint)
    )
    (let ((campaign-opt (map-get? campaigns { id: campaign-id })))
        (match campaign-opt
            campaign-data (begin
                (asserts! (is-eq (get artist campaign-data) tx-sender)
                    (err "Solo el artista puede cerrar")
                )
                (asserts! (get active campaign-data) (err "Campana ya cerrada"))

                (let (
                        (total (get raised campaign-data))
                        (goal (get goal campaign-data))
                        (count (get donor-count campaign-data))
                    )
                    (if (>= total goal)
                        (let ((winner (select-winner-with-seed campaign-id count seed)))
                            (begin
                                ;; distribuir fondos
                                (let (
                                        (platform-fee (/ (* total PLATFORM_FEE_PERCENT) u100))
                                        (artist-amount (- total platform-fee))
                                    )
                                    (unwrap-panic (stx-transfer? platform-fee tx-sender
                                        PLATFORM_WALLET
                                    ))
                                    (unwrap-panic (stx-transfer? artist-amount tx-sender
                                        (get artist campaign-data)
                                    ))
                                )
                                (map-set campaigns { id: campaign-id }
                                    (merge campaign-data {
                                        active: false,
                                        winner: (some winner),
                                    })
                                )
                                (ok (some winner))
                            )
                        )
                        (err "Meta no alcanzada")
                    )
                )
            )
            (err "Campana no encontrada")
        )
    )
)

;; Seleccion pseudoaleatoria del ganador
(define-private (select-winner-with-seed
        (campaign-id uint)
        (count uint)
        (seed uint)
    )
    (if (> count u0)
        (let ((idx (mod seed count)))
            (match (map-get? campaign-donors {
                campaign-id: campaign-id,
                index: idx,
            })
                donor
                donor
                tx-sender
            )
        )
        tx-sender
    )
)

;; Lecturas publicas
(define-read-only (get-donation
        (campaign-id uint)
        (donor principal)
    )
    (match (map-get? donations {
        campaign-id: campaign-id,
        donor: donor,
    })
        entry (ok entry)
        (err "no-donation")
    )
)

(define-read-only (get-campaign-counter)
    (ok (var-get campaign-counter))
)

(define-read-only (get-campaign (campaign-id uint))
    (match (map-get? campaigns { id: campaign-id })
        entry (ok entry)
        (err "no-campaign")
    )
)
