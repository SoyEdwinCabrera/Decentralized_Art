;; -----------------------------------------------------
;; Contrato: demo-artwork-token.clar
;; Autor: Edwin Cabrera
;; Descripcion: Define los NFT unicos de cada obra de arte
;; -----------------------------------------------------

(impl-trait .artwork-trait.art-nft-trait)

;; -----------------------------------------------------
;; VARIABLES GLOBALES
;; -----------------------------------------------------

(define-data-var total-supply uint u0) ;; cantidad total de NFTs emitidos
(define-map token-owners uint principal) ;; token-id - propietario
(define-map token-uri uint (string-ascii 256)) ;; token-id - metadatos URI

(define-constant CONTRACT-OWNER tx-sender) ;; el despliegue inicial asigna el dueNIo

;; -----------------------------------------------------
;; FUNCIONES PuBLICAS
;; -----------------------------------------------------

;; ACUNIAR (mint) un nuevo NFT
(define-public (mint-artwork (recipient principal) (metadata-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) (err "Solo el dueNIo puede acuniar"))
    (let (
          (new-id (+ u1 (var-get total-supply)))
         )
      (map-set token-owners {token-id: new-id} recipient)
      (map-set token-uri {token-id: new-id} metadata-uri)
      (var-set total-supply new-id)
      (ok new-id)
    )
  )
)

;; TRANSFERIR NFT
(define-public (transfer-artwork (token-id uint) (new-owner principal))
  (let ((owner-opt (map-get? token-owners {token-id: token-id})))
    (match owner-opt owner
      (if (is-eq owner tx-sender)
        (begin
          (map-set token-owners {token-id: token-id} new-owner)
          (ok true)
        )
        (err "not-authorized")
      )
      (err "token-not-found")
    )
  )
)

;; CONSULTAR PROPIETARIO
(define-read-only (get-artwork-owner (token-id uint))
  (map-get? token-owners {token-id: token-id})
)

;; CONSULTAR METADATOS (URI)
(define-read-only (get-artwork-uri (token-id uint))
  (map-get? token-uri {token-id: token-id})
)

;; TOTAL DE NFTs CREADOS
(define-read-only (get-total-supply)
  (var-get total-supply)
)
