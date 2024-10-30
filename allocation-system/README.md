# Resource Allocation Smart Contract

A Clarity smart contract for managing and allocating resources with priority levels, user roles, and administrative controls.

## About

This smart contract implements a comprehensive resource allocation system with features including:
- Resource type management with configurable supply and pricing
- User role-based access control
- Priority-based allocation requests
- Resource transfer capabilities
- Emergency controls and maintenance mode
- Price history tracking
- Blacklist management

## Constants

### Error Codes
- `ERROR_UNAUTHORIZED_ACCESS (u100)`: User doesn't have required permissions
- `ERROR_INVALID_RESOURCE_AMOUNT (u101)`: Resource amount is invalid
- `ERROR_INSUFFICIENT_RESOURCE_BALANCE (u102)`: Insufficient balance for operation
- `ERROR_RESOURCE_TYPE_NOT_FOUND (u103)`: Resource type doesn't exist
- `ERROR_CONTRACT_ALREADY_INITIALIZED (u104)`: Contract has already been initialized
- `ERROR_INVALID_TRANSFER_DESTINATION (u105)`: Invalid transfer recipient
- `ERROR_RESOURCE_LIMIT_EXCEEDED (u106)`: Resource allocation exceeds limits
- `ERROR_INVALID_PRIORITY_LEVEL (u107)`: Invalid priority level specified
- `ERROR_RESOURCE_LOCKED (u108)`: Resource is currently locked
- `ERROR_EXPIRED_REQUEST (u109)`: Allocation request has expired

## Core Features

### User Roles and Priorities
The contract supports five priority levels:
1. USER (Level 1)
2. VERIFIED (Level 2)
3. BUSINESS (Level 3)
4. PREMIUM (Level 4)
5. ADMIN (Level 5)

### Resource Management
- Register new resource types with customizable parameters
- Update resource prices with historical tracking
- Lock/unlock resources
- Configure minimum and maximum allocation limits
- Set resource priority levels

### Allocation System
- Submit allocation requests with purpose documentation
- Priority-based allocation processing
- 24-hour request expiration
- Transfer allocations between users

### Administrative Controls
- System initialization
- Maintenance mode
- User role management
- Blacklist management
- Emergency controls
- System parameter updates

## Public Functions

### System Management
```clarity
(initialize-resource-allocation-system)
(update-system-parameters (new-limit uint) (new-emergency-contact principal))
(enter-maintenance-mode)
(exit-maintenance-mode)
```

### Resource Management
```clarity
(register-new-resource-type 
    (resource-type-id uint) 
    (resource-name (string-ascii 64)) 
    (initial-supply uint) 
    (unit-price uint)
    (min-allocation uint)
    (max-allocation uint)
    (priority-level uint))
(update-resource-price (resource-type-id uint) (new-price uint))
(lock-resource (resource-type-id uint))
(unlock-resource (resource-type-id uint))
```

### User Management
```clarity
(update-user-role (user-address principal) (new-role (string-ascii 20)))
(blacklist-user (user-address principal))
(remove-user-blacklist (user-address principal))
```

### Resource Allocation
```clarity
(submit-resource-allocation-request 
    (resource-type-id uint) 
    (requested-quantity uint)
    (allocation-purpose (string-ascii 128)))
(transfer-allocation (recipient principal) (resource-type-id uint) (transfer-amount uint))
```

## Read-Only Functions

```clarity
(get-user-resource-balance (user-address principal))
(get-resource-type-details (resource-type-id uint))
(get-allocation-request-details (allocation-request-id uint))
(get-user-allocation-history (user-address principal))
(get-resource-price-history (resource-type-id uint))
(get-system-status)
```

## Security Features

1. Role-based access control
2. Resource priority levels
3. Blacklist functionality
4. Emergency controls
5. Maintenance mode
6. Resource locking
7. Allocation limits
8. Request expiration
9. Authorization checks

## Usage Requirements

1. Contract must be initialized before use
2. Only contract administrator can perform administrative functions
3. Users must have appropriate priority levels for resource allocation
4. Resource transfers require both sender and recipient to be authorized
5. Allocation requests expire after 24 hours (144 blocks)