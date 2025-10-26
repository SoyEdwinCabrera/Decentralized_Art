;; demo-marketplace.clar - marketplace integrado con demo-artwork-token
;; Todo el codigo y comentarios sin tildes ni letra n-tilde en el contrato

(impl-trait .demo-artwork-token.nft-trait)


(define-constant PLATFORM_FEE_PERCENT u5) ;; 5 por ciento
(define-constant PLATFORM_WALLET 'ST3J2GVMMM2R07ZFBJDWTYEYAR8FZH5WKDTFJ9AHA)

(define-map listings
  ((id uint))
  ((seller principal)
   (token-id uint)
   (price uint)
   (active bool))
)

(define-data-var next-listing-id uint u1)

(define-public (create-listing (token-id uint) (price uint))
  (begin
    (asserts! (> price u0) (err u400))
    ;; transferir el NFT al marketplace antes de listarlo
    (try! (contract-call? .demo-artwork-token transfer-artwork token-id tx-sender (as-contract tx-sender)))
    (let ((listing-id (var-get next-listing-id)))
      (map-set listings
        {id: listing-id}
        {
          seller: tx-sender,
          token-id: token-id,
          price: price,
          active: true
        })
      (var-set next-listing-id (+ listing-id u1))
      (ok (tuple (listing-id listing-id) (price price)))
    )
  )
)

(define-public (buy-listing (listing-id uint))
  (let ((listing-opt (map-get? listings {id: listing-id})))
    (match listing-opt listing-data
      (if (get active listing-data)
          (let ((price (get price listing-data))
                (seller (get seller listing-data))
                (token-id (get token-id listing-data))
                (fee (/ (* price PLATFORM_FEE_PERCENT) u100))
                (seller-amount (- price fee)))
            (begin
              ;; recibir precio en el contrato, luego repartir
              (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
              (try! (stx-transfer? seller-amount (as-contract tx-sender) seller))
              (try! (stx-transfer? fee (as-contract tx-sender) PLATFORM_WALLET))
              ;; transferir NFT al comprador
              (try! (contract-call? .demo-artwork-token transfer-artwork token-id seller tx-sender))
              ;; desactivar listado
              (map-set listings {id: listing-id} (merge listing-data {active: false}))
              (ok (tuple (buyer tx-sender) (token-id token-id) (price price)))
            )
          (err u404))
      (err u404)
    )
  )
)

(define-public (cancel-listing (listing-id uint))
  (let ((listing-opt (map-get? listings {id: listing-id})))
    (match listing-opt listing-data
      (if (and (get active listing-data) (is-eq (get seller listing-data) tx-sender))
          (begin
            ;; devolver NFT al vendedor
            (try! (contract-call? .demo-artwork-token transfer-artwork (get token-id listing-data) (as-contract tx-sender) tx-sender))
            (map-set listings {id: listing-id} (merge listing-data {active: false}))
            (ok (tuple (listing-id listing-id) (status "Cancelled")))
          (err u403))
      (err u404)
    )
  )
)

(define-read-only (get-listing (listing-id uint))
  (match (map-get? listings {id: listing-id})
    listing-data (ok listing-data)
    (err u404)
  )
)
)
)
