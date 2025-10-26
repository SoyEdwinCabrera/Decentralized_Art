(define-map listings
  {token-id: uint}
  {
    seller: principal,
    price: uint
  }
)

(define-public (list-artwork (token-id uint) (price uint))
  (begin
    ;; Solo el propietario actual del token puede listar
    (let ((owner (unwrap! (contract-call? .demo-artwork-token get-owner token-id) (err u404))))
      (if (is-eq owner tx-sender)
          (begin
            (map-set listings {token-id: token-id} {seller: tx-sender, price: price})
            (ok "Artwork listed successfully")
          )
          (err u403)
      )
    )
  )
)

(define-read-only (get-listing (token-id uint))
  (map-get? listings {token-id: token-id})
)

(define-public (buy-listing (token-id uint))
  (let (
        (listing (map-get? listings {token-id: token-id}))
      )
    (match listing listing-data
      (let (
            (seller (get seller listing-data))
            (price (get price listing-data))
          )
        ;; Verificar que el comprador no sea el mismo que el vendedor
        (if (is-eq seller tx-sender)
            (err u400) ;; No puedes comprar tu propio NFT
            (begin
              ;; Transferir STX del comprador al vendedor
              (try! (stx-transfer? price tx-sender seller))

              ;; Transferir la propiedad del NFT al comprador
              (try! (contract-call? .demo-artwork-token transfer-artwork token-id tx-sender))

              ;; Eliminar la oferta del marketplace
              (map-delete listings {token-id: token-id})

              (ok "Purchase completed successfully")
            )
        )
      )
      (err u404) ;; Si no hay listado para ese token-id
    )
  )
)
