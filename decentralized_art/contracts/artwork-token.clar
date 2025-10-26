;; ---------------------------------------------------------
;; Demo Artwork Token - NFT contract for Decentralized Art
;; ---------------------------------------------------------
;; demo-artwork-token.clar
;; NFT basico para el ecosistema Demo Decentralized Art

(define-data-var next-id uint u1)

(define-map token-owners {token-id: uint} principal)
(define-map token-uri {token-id: uint} (string-ascii 256))

;; Retorna el propietario de un token
(define-read-only (get-owner (token-id uint))
  (map-get? token-owners {token-id: token-id})
)

;; Retorna la URI asociada al token
(define-read-only (get-token-uri (token-id uint))
  (map-get? token-uri {token-id: token-id})
)

;; Crea un nuevo NFT
(define-public (mint-artwork (recipient principal) (metadata-uri (string-ascii 256)))
  (let ((new-id (var-get next-id)))
    (map-set token-owners {token-id: new-id} recipient)
    (map-set token-uri {token-id: new-id} metadata-uri)
    (var-set next-id (+ new-id u1))
    (ok new-id)
  )
)

;; Transfiere el token a otro usuario
(define-public (transfer-artwork (token-id uint) (new-owner principal))
  (let ((owner-opt (map-get? token-owners {token-id: token-id})))
    (match owner-opt owner
      (if (is-eq owner tx-sender)
          (begin
            (map-set token-owners {token-id: token-id} new-owner)
            (ok true)
          )
          (err u403)
      )
      (err u404)
    )
  )
)
