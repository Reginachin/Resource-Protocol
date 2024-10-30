;; Resource Allocation Contract
;; Handles resource management, allocation, and tracking

;; Constants
(define-constant CONTRACT_ADMINISTRATOR tx-sender)
(define-constant ERROR_UNAUTHORIZED_ACCESS (err u100))
(define-constant ERROR_INVALID_RESOURCE_AMOUNT (err u101))
(define-constant ERROR_INSUFFICIENT_RESOURCE_BALANCE (err u102))
(define-constant ERROR_RESOURCE_TYPE_NOT_FOUND (err u103))
(define-constant ERROR_CONTRACT_ALREADY_INITIALIZED (err u104))

;; Data Variables
(define-data-var contract-status-initialized bool false)
(define-data-var total-allocation-requests uint u0)
(define-data-var resource-allocation-system-paused bool false)

;; Data Maps
(define-map user-resource-balances principal uint)
(define-map available-resource-types uint {
    resource-name: (string-ascii 64),
    resource-total-supply: uint,
    resource-available-quantity: uint,
    resource-unit-price: uint
})
(define-map pending-allocation-requests uint {
    requesting-user: principal,
    requested-amount: uint,
    requested-resource-type: uint,
    request-status: (string-ascii 20)
})

;; Private Functions
(define-private (is-administrator-access)
    (is-eq tx-sender CONTRACT_ADMINISTRATOR)
)

(define-private (validate-resource-amount (resource-quantity uint))
    (> resource-quantity u0)
)

(define-private (verify-resource-type-exists (resource-type-id uint))
    (match (map-get? available-resource-types resource-type-id)
        resource-data true
        false
    )
)

;; Read Only Functions
(define-read-only (get-user-resource-balance (user-address principal))
    (default-to u0 (map-get? user-resource-balances user-address))
)

(define-read-only (get-resource-type-details (resource-type-id uint))
    (map-get? available-resource-types resource-type-id)
)

(define-read-only (get-allocation-request-details (allocation-request-id uint))
    (map-get? pending-allocation-requests allocation-request-id)
)

(define-read-only (get-contract-administrator)
    CONTRACT_ADMINISTRATOR
)

;; Public Functions
(define-public (initialize-resource-allocation-system)
    (begin
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (asserts! (not (var-get contract-status-initialized)) ERROR_CONTRACT_ALREADY_INITIALIZED)
        (var-set contract-status-initialized true)
        (var-set total-allocation-requests u0)
        (var-set resource-allocation-system-paused false)
        (ok true)
    )
)

(define-public (register-new-resource-type 
    (resource-type-id uint) 
    (resource-name (string-ascii 64)) 
    (initial-supply uint) 
    (unit-price uint))
    (begin
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (asserts! (validate-resource-amount initial-supply) ERROR_INVALID_RESOURCE_AMOUNT)
        (asserts! (validate-resource-amount unit-price) ERROR_INVALID_RESOURCE_AMOUNT)
        (map-set available-resource-types resource-type-id {
            resource-name: resource-name,
            resource-total-supply: initial-supply,
            resource-available-quantity: initial-supply,
            resource-unit-price: unit-price
        })
        (ok true)
    )
)

(define-public (submit-resource-allocation-request (resource-type-id uint) (requested-quantity uint))
    (let (
        (resource-type-info (unwrap! (map-get? available-resource-types resource-type-id) ERROR_RESOURCE_TYPE_NOT_FOUND))
        (new-request-id (+ (var-get total-allocation-requests) u1))
    )
        (asserts! (not (var-get resource-allocation-system-paused)) ERROR_UNAUTHORIZED_ACCESS)
        (asserts! (validate-resource-amount requested-quantity) ERROR_INVALID_RESOURCE_AMOUNT)
        (asserts! (<= requested-quantity (get resource-available-quantity resource-type-info)) ERROR_INSUFFICIENT_RESOURCE_BALANCE)
        
        (map-set pending-allocation-requests new-request-id {
            requesting-user: tx-sender,
            requested-amount: requested-quantity,
            requested-resource-type: resource-type-id,
            request-status: "PENDING"
        })
        (var-set total-allocation-requests new-request-id)
        (ok new-request-id)
    )
)

(define-public (approve-resource-allocation-request (allocation-request-id uint))
    (let (
        (allocation-request (unwrap! (map-get? pending-allocation-requests allocation-request-id) ERROR_RESOURCE_TYPE_NOT_FOUND))
        (resource-type-info (unwrap! (map-get? available-resource-types (get requested-resource-type allocation-request)) ERROR_RESOURCE_TYPE_NOT_FOUND))
        (requester-current-balance (get-user-resource-balance (get requesting-user allocation-request)))
    )
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (asserts! (is-eq (get request-status allocation-request) "PENDING") ERROR_UNAUTHORIZED_ACCESS)
        
        ;; Update resource availability
        (map-set available-resource-types (get requested-resource-type allocation-request) 
            (merge resource-type-info { 
                resource-available-quantity: (- (get resource-available-quantity resource-type-info) 
                                             (get requested-amount allocation-request)) 
            })
        )
        
        ;; Update requester's balance
        (map-set user-resource-balances (get requesting-user allocation-request) 
            (+ requester-current-balance (get requested-amount allocation-request))
        )
        
        ;; Update request status
        (map-set pending-allocation-requests allocation-request-id 
            (merge allocation-request { request-status: "APPROVED" })
        )
        (ok true)
    )
)

(define-public (reject-resource-allocation-request (allocation-request-id uint))
    (let (
        (allocation-request (unwrap! (map-get? pending-allocation-requests allocation-request-id) ERROR_RESOURCE_TYPE_NOT_FOUND))
    )
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (asserts! (is-eq (get request-status allocation-request) "PENDING") ERROR_UNAUTHORIZED_ACCESS)
        
        (map-set pending-allocation-requests allocation-request-id 
            (merge allocation-request { request-status: "REJECTED" })
        )
        (ok true)
    )
)

(define-public (return-allocated-resource (resource-type-id uint) (return-amount uint))
    (let (
        (resource-type-info (unwrap! (map-get? available-resource-types resource-type-id) ERROR_RESOURCE_TYPE_NOT_FOUND))
        (user-current-balance (get-user-resource-balance tx-sender))
    )
        (asserts! (validate-resource-amount return-amount) ERROR_INVALID_RESOURCE_AMOUNT)
        (asserts! (<= return-amount user-current-balance) ERROR_INSUFFICIENT_RESOURCE_BALANCE)
        
        ;; Update resource availability
        (map-set available-resource-types resource-type-id 
            (merge resource-type-info { 
                resource-available-quantity: (+ (get resource-available-quantity resource-type-info) return-amount) 
            })
        )
        
        ;; Update user balance
        (map-set user-resource-balances tx-sender 
            (- user-current-balance return-amount)
        )
        (ok true)
    )
)

(define-public (pause-resource-allocation-system)
    (begin
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (var-set resource-allocation-system-paused true)
        (ok true)
    )
)

(define-public (resume-resource-allocation-system)
    (begin
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (var-set resource-allocation-system-paused false)
        (ok true)
    )
)