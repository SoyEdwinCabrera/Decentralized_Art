;; -------------------------------------------------------------
;; CONTRACT: artwork-campaign.clar
;; Decentralized_Art - Mecenazgo y sorteos justos
;; -------------------------------------------------------------

(define-constant PLATFORM_FEE_PERCENT u10)
(define-constant PLATFORM_WALLET 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) ;; direccion de la plataforma

(define-data-var campaign-counter uint u0)

;; campaigns ahora incluye donor-count en vez de lista de donantes
(define-map campaigns
  {id: uint}
  {
    artist: principal,
    goal: uint,
    raised: uint,
    deadline: uint,
    active: bool,
    donor-count: uint,
    winner: (optional principal),
    ipfs-hash: (optional (string-ascii 256))
  }
)

;; donors almacenados en un mapa indexado por campaign-id y index
(define-map campaign-donors
  {campaign-id: uint, index: uint}
  principal)

(define-map donations
  {campaign-id: uint, donor: principal}
  {amount: uint})

;; Crear una nueva campana
(define-public (create-campaign (goal uint) (deadline uint) (ipfs-hash (string-ascii 256)))
  (let ((current (var-get campaign-counter)))
    (begin
      ;; increment counter
      (var-set campaign-counter (+ current u1))
      (let ((new-id (+ current u1))
            (ipfs-opt (if (is-eq ipfs-hash "") none (some ipfs-hash))))
        (map-set campaigns
          {id: new-id}
          {
            artist: tx-sender,
            goal: goal,
            raised: u0,
            deadline: deadline,
            active: true,
            donor-count: u0,
            ipfs-hash: ipfs-opt,
            winner: none
          })
        (ok (tuple (id new-id) (msg "Campaign created!") (price goal) (fee deadline) (ipfs ipfs-opt)))))))

;; Donar STX a una campana activa
(define-public (donate (campaign-id uint) (amount uint))
  (let ((campaign-opt (map-get? campaigns {id: campaign-id})))
    (match campaign-opt
      campaign-data
        (if (get active campaign-data)
            (let ((count (get donor-count campaign-data))
                  (donor-key {campaign-id: campaign-id, donor: tx-sender}))
              (begin
                ;; validaciones
                (asserts! (> amount u0) (err "Monto invalido"))
                (asserts! (< count u100) (err "Maximo de donantes alcanzado"))
                ;; registrar donacion
                (map-set donations donor-key {amount: amount})
                ;; almacenar donante en map por indice
                (map-set campaign-donors {campaign-id: campaign-id, index: count} tx-sender)
                ;; incrementar contador y actualizar raised
                (map-set campaigns
                  {id: campaign-id}
                  (merge campaign-data {
                    raised: (+ (get raised campaign-data) amount),
                    donor-count: (+ count u1)
                  }))
                ;; retorno consistente: response bool
                (ok true)))
            (err "Campana no activa"))
      (err "Campana no encontrada"))))


;; Cerrar campana y ejecutar sorteo
(define-public (close-campaign (campaign-id uint) (seed uint))
  (let ((campaign-opt (map-get? campaigns {id: campaign-id})))
    (match campaign-opt
      campaign-data
        (begin
          (asserts! (is-eq (get artist campaign-data) tx-sender) (err "Solo el artista puede cerrar"))
          (asserts! (get active campaign-data) (err "Campana ya cerrada"))
          (let ((total (get raised campaign-data))
                (goal (get goal campaign-data))
                (count (get donor-count campaign-data)))
            (if (>= total goal)
              (let ((winner (select-winner-with-seed campaign-id count seed)))
                (begin
                  ;; comprobar transferencias (unwrap-panic para manejar responses)
                  (let ((platform-fee (/ (* total PLATFORM_FEE_PERCENT) u100))
                        (artist-amount (- total platform-fee)))
                    (unwrap-panic (stx-transfer? platform-fee tx-sender PLATFORM_WALLET))
                    (unwrap-panic (stx-transfer? artist-amount tx-sender (get artist campaign-data))))
                  (map-set campaigns
                    {id: campaign-id}
                    (merge campaign-data {active: false, winner: (some winner)}))
                  (ok (some winner))))
              (err "Meta no alcanzada"))))
      (err "Campana no encontrada"))))

;; Seleccion pseudoaleatoria de ganador usando campaign-donors map
(define-private (select-winner-with-seed (campaign-id uint) (count uint) (seed uint))
  (if (> count u0)
      (let ((idx (mod seed count)))
        (match (map-get? campaign-donors {campaign-id: campaign-id, index: idx})
          donor donor
          tx-sender))
      tx-sender))

;; Comprobar que la donacion se registro
(define-read-only (get-donation (campaign-id uint) (donor principal))
  (match (map-get? donations {campaign-id: campaign-id, donor: donor})
    entry (ok entry)
    (err "no-donation")))

;; Informacion de la campana
(define-read-only (get-campaign-counter)
  (ok (var-get campaign-counter)))

(define-read-only (get-campaign (campaign-id uint))
  (match (map-get? campaigns {id: campaign-id})
    entry (ok entry)
    (err "no-campaign")))
