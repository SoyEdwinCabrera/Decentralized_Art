;; Contrato: demo-platform-wallet.clar
;; Funcion: Recibir comisiones y permitir al administrador retirarlas

(define-constant ADMIN 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) ;; Reemplaza con tu address

(define-data-var total-fees uint u0)

;; Recibe comisiones de otros contratos (como el marketplace)
(define-public (deposit-fee (amount uint))
    (begin
        (var-set total-fees (+ (var-get total-fees) amount))
        (ok "Fee deposited successfully")
    )
)

;; Solo el admin puede retirar los fondos acumulados
(define-public (withdraw-fees
        (recipient principal)
        (amount uint)
    )
    (if (is-eq tx-sender ADMIN)
        (begin
            (try! (stx-transfer? amount (as-contract tx-sender) recipient))
            (var-set total-fees (- (var-get total-fees) amount))
            (ok "Fees withdrawn successfully")
        )
        (err u403)
    )
)

(define-read-only (get-total-fees)
    (var-get total-fees)
)
