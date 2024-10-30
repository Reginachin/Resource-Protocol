;; Resource Allocation Contract V2
;; Enhanced version with additional features

;; Error Constants
(define-constant CONTRACT_ADMINISTRATOR tx-sender)
(define-constant ERROR_UNAUTHORIZED_ACCESS (err u100))
(define-constant ERROR_INVALID_RESOURCE_AMOUNT (err u101))
(define-constant ERROR_INSUFFICIENT_RESOURCE_BALANCE (err u102))
(define-constant ERROR_RESOURCE_TYPE_NOT_FOUND (err u103))
(define-constant ERROR_CONTRACT_ALREADY_INITIALIZED (err u104))
(define-constant ERROR_INVALID_TRANSFER_DESTINATION (err u105))
(define-constant ERROR_RESOURCE_LIMIT_EXCEEDED (err u106))
(define-constant ERROR_INVALID_PRIORITY_LEVEL (err u107))
(define-constant ERROR_RESOURCE_LOCKED (err u108))
(define-constant ERROR_EXPIRED_REQUEST (err u109))

;; Data Variables
(define-data-var contract-status-initialized bool false)
(define-data-var total-allocation-requests uint u0)
(define-data-var resource-allocation-system-paused bool false)
(define-data-var system-maintenance-mode bool false)
(define-data-var global-resource-limit uint u1000000)
(define-data-var emergency-contact-address principal CONTRACT_ADMINISTRATOR)

;; Data Maps
(define-map user-resource-balances principal uint)
(define-map available-resource-types uint {
    resource-name: (string-ascii 64),
    resource-total-supply: uint,
    resource-available-quantity: uint,
    resource-unit-price: uint,
    resource-locked: bool,
    resource-priority-level: uint,
    minimum-allocation: uint,
    maximum-allocation: uint,
    allocation-timelock: uint,
    last-price-update: uint
})

(define-map pending-allocation-requests uint {
    requesting-user: principal,
    requested-amount: uint,
    requested-resource-type: uint,
    request-status: (string-ascii 20),
    request-priority: uint,
    request-timestamp: uint,
    expiration-time: uint,
    allocation-purpose: (string-ascii 128)
})

(define-map user-allocation-history principal (list 10 uint))
(define-map resource-price-history uint (list 10 uint))
(define-map user-roles principal (string-ascii 20))
(define-map blacklisted-users principal bool)
(define-map resource-dependencies uint (list 5 uint))

;; Private Functions
(define-private (is-administrator-access)
    (is-eq tx-sender CONTRACT_ADMINISTRATOR)
)

(define-private (validate-resource-amount (resource-quantity uint))
    (and 
        (> resource-quantity u0)
        (<= resource-quantity (var-get global-resource-limit))
    )
)

(define-private (verify-resource-type-exists (resource-type-id uint))
    (match (map-get? available-resource-types resource-type-id)
        resource-data true
        false
    )
)

(define-private (check-user-authorization (user-address principal))
    (and
        (not (default-to false (map-get? blacklisted-users user-address)))
        (>= (get-user-priority-level user-address) u1)
    )
)

;; Private Functions
(define-private (get-user-priority-level (user-address principal))
    (let ((user-role (default-to "USER" (map-get? user-roles user-address))))
        (if (is-eq user-role "ADMIN")
            u5
            (if (is-eq user-role "PREMIUM")
                u4
                (if (is-eq user-role "BUSINESS")
                    u3
                    (if (is-eq user-role "VERIFIED")
                        u2
                        u1)))))) ;; Default USER level

;; Private Function
(define-private (record-price-update (resource-type-id uint) (new-price uint))
    (let (
        (current-history (default-to (list) (map-get? resource-price-history resource-type-id)))
        (new-history (unwrap! (as-max-len? (concat (list new-price) current-history) u10) (err u0)))
    )
        (ok (map-set resource-price-history resource-type-id new-history))
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

(define-read-only (get-user-allocation-history (user-address principal))
    (default-to (list) (map-get? user-allocation-history user-address))
)

(define-read-only (get-resource-price-history (resource-type-id uint))
    (default-to (list) (map-get? resource-price-history resource-type-id))
)

(define-read-only (get-system-status)
    {
        initialized: (var-get contract-status-initialized),
        paused: (var-get resource-allocation-system-paused),
        maintenance: (var-get system-maintenance-mode),
        global-limit: (var-get global-resource-limit),
        emergency-contact: (var-get emergency-contact-address)
    }
)

;; Public Functions
;; System Management Functions
(define-public (initialize-resource-allocation-system)
    (begin
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (asserts! (not (var-get contract-status-initialized)) ERROR_CONTRACT_ALREADY_INITIALIZED)
        (var-set contract-status-initialized true)
        (var-set total-allocation-requests u0)
        (var-set resource-allocation-system-paused false)
        (var-set system-maintenance-mode false)
        (ok true)
    )
)

(define-public (update-system-parameters (new-limit uint) (new-emergency-contact principal))
    (begin
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (var-set global-resource-limit new-limit)
        (var-set emergency-contact-address new-emergency-contact)
        (ok true)
    )
)

;; Resource Management Functions
(define-public (register-new-resource-type 
    (resource-type-id uint) 
    (resource-name (string-ascii 64)) 
    (initial-supply uint) 
    (unit-price uint)
    (min-allocation uint)
    (max-allocation uint)
    (priority-level uint))
    (begin
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (asserts! (validate-resource-amount initial-supply) ERROR_INVALID_RESOURCE_AMOUNT)
        (asserts! (validate-resource-amount unit-price) ERROR_INVALID_RESOURCE_AMOUNT)
        (asserts! (<= priority-level u5) ERROR_INVALID_PRIORITY_LEVEL)
        (map-set available-resource-types resource-type-id {
            resource-name: resource-name,
            resource-total-supply: initial-supply,
            resource-available-quantity: initial-supply,
            resource-unit-price: unit-price,
            resource-locked: false,
            resource-priority-level: priority-level,
            minimum-allocation: min-allocation,
            maximum-allocation: max-allocation,
            allocation-timelock: u0,
            last-price-update: block-height
        })
        (ok true)
    )
)

(define-public (update-resource-price (resource-type-id uint) (new-price uint))
    (let (
        (resource-type-info (unwrap! (map-get? available-resource-types resource-type-id) ERROR_RESOURCE_TYPE_NOT_FOUND))
    )
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (asserts! (validate-resource-amount new-price) ERROR_INVALID_RESOURCE_AMOUNT)
        
        ;; Record price history and handle potential error
        (try! (record-price-update resource-type-id new-price))
        
        ;; Update resource price
        (map-set available-resource-types resource-type-id 
            (merge resource-type-info {
                resource-unit-price: new-price,
                last-price-update: block-height
            })
        )
        (ok true)
    )
)

;; User Management Functions
(define-public (update-user-role (user-address principal) (new-role (string-ascii 20)))
    (begin
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (map-set user-roles user-address new-role)
        (ok true)
    )
)

(define-public (blacklist-user (user-address principal))
    (begin
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (map-set blacklisted-users user-address true)
        (ok true)
    )
)

(define-public (remove-user-blacklist (user-address principal))
    (begin
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (map-set blacklisted-users user-address false)
        (ok true)
    )
)

;; Resource Allocation Functions
(define-public (submit-resource-allocation-request 
    (resource-type-id uint) 
    (requested-quantity uint)
    (allocation-purpose (string-ascii 128)))
    (let (
        (resource-type-info (unwrap! (map-get? available-resource-types resource-type-id) ERROR_RESOURCE_TYPE_NOT_FOUND))
        (new-request-id (+ (var-get total-allocation-requests) u1))
        (user-priority (get-user-priority-level tx-sender))
    )
        (asserts! (not (var-get resource-allocation-system-paused)) ERROR_UNAUTHORIZED_ACCESS)
        (asserts! (not (var-get system-maintenance-mode)) ERROR_UNAUTHORIZED_ACCESS)
        (asserts! (check-user-authorization tx-sender) ERROR_UNAUTHORIZED_ACCESS)
        (asserts! (not (get resource-locked resource-type-info)) ERROR_RESOURCE_LOCKED)
        (asserts! (validate-resource-amount requested-quantity) ERROR_INVALID_RESOURCE_AMOUNT)
        (asserts! (<= requested-quantity (get resource-available-quantity resource-type-info)) ERROR_INSUFFICIENT_RESOURCE_BALANCE)
        (asserts! (>= requested-quantity (get minimum-allocation resource-type-info)) ERROR_INVALID_RESOURCE_AMOUNT)
        (asserts! (<= requested-quantity (get maximum-allocation resource-type-info)) ERROR_RESOURCE_LIMIT_EXCEEDED)
        (asserts! (>= user-priority (get resource-priority-level resource-type-info)) ERROR_UNAUTHORIZED_ACCESS)
        
        (map-set pending-allocation-requests new-request-id {
            requesting-user: tx-sender,
            requested-amount: requested-quantity,
            requested-resource-type: resource-type-id,
            request-status: "PENDING",
            request-priority: user-priority,
            request-timestamp: block-height,
            expiration-time: (+ block-height u144), ;; 24 hour expiration
            allocation-purpose: allocation-purpose
        })
        (var-set total-allocation-requests new-request-id)
        (ok new-request-id)
    )
)

(define-public (transfer-allocation (recipient principal) (resource-type-id uint) (transfer-amount uint))
    (let (
        (sender-balance (get-user-resource-balance tx-sender))
        (recipient-balance (get-user-resource-balance recipient))
        (resource-type-info (unwrap! (map-get? available-resource-types resource-type-id) ERROR_RESOURCE_TYPE_NOT_FOUND))
    )
        (asserts! (not (var-get resource-allocation-system-paused)) ERROR_UNAUTHORIZED_ACCESS)
        (asserts! (check-user-authorization tx-sender) ERROR_UNAUTHORIZED_ACCESS)
        (asserts! (check-user-authorization recipient) ERROR_INVALID_TRANSFER_DESTINATION)
        (asserts! (<= transfer-amount sender-balance) ERROR_INSUFFICIENT_RESOURCE_BALANCE)
        (asserts! (not (get resource-locked resource-type-info)) ERROR_RESOURCE_LOCKED)
        
        ;; Update balances
        (map-set user-resource-balances tx-sender (- sender-balance transfer-amount))
        (map-set user-resource-balances recipient (+ recipient-balance transfer-amount))
        (ok true)
    )
)

;; Emergency Functions
(define-public (enter-maintenance-mode)
    (begin
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (var-set system-maintenance-mode true)
        (var-set resource-allocation-system-paused true)
        (ok true)
    )
)

(define-public (exit-maintenance-mode)
    (begin
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (var-set system-maintenance-mode false)
        (var-set resource-allocation-system-paused false)
        (ok true)
    )
)

(define-public (lock-resource (resource-type-id uint))
    (let (
        (resource-type-info (unwrap! (map-get? available-resource-types resource-type-id) ERROR_RESOURCE_TYPE_NOT_FOUND))
    )
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (map-set available-resource-types resource-type-id 
            (merge resource-type-info { resource-locked: true })
        )
        (ok true)
    )
)

(define-public (unlock-resource (resource-type-id uint))
    (let (
        (resource-type-info (unwrap! (map-get? available-resource-types resource-type-id) ERROR_RESOURCE_TYPE_NOT_FOUND))
    )
        (asserts! (is-administrator-access) ERROR_UNAUTHORIZED_ACCESS)
        (map-set available-resource-types resource-type-id 
            (merge resource-type-info { resource-locked: false })
        )
        (ok true)
    )
)