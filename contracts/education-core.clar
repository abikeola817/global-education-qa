
;; title: education-core
;; version: 1.0.0
;; summary: Global Education Quality Assurance Core Contract
;; description: Manages international education standards, institution validation, and quality monitoring

;; Constants for error handling
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-ALREADY-EXISTS (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-INVALID-SCORE (err u103))
(define-constant ERR-INVALID-STATUS (err u104))
(define-constant ERR-INSUFFICIENT-PERMISSIONS (err u105))

;; Contract owner and administrative roles
(define-data-var contract-owner principal tx-sender)
(define-data-var standard-version uint u1)
(define-data-var total-institutions uint u0)
(define-data-var total-standards uint u0)

;; Quality score thresholds
(define-constant MIN-QUALITY-SCORE u60)
(define-constant MAX-QUALITY-SCORE u100)

;; Institution status constants
(define-constant STATUS-PENDING u1)
(define-constant STATUS-VALIDATED u2)
(define-constant STATUS-ACCREDITED u3)
(define-constant STATUS-SUSPENDED u4)

;; Data structure for education quality standards
(define-map quality-standards
  { standard-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    version: uint,
    created-by: principal,
    created-at: uint,
    status: uint,
    min-score: uint,
    category: (string-ascii 50)
  }
)

;; Data structure for educational institutions
(define-map institutions
  { institution-id: uint }
  {
    name: (string-ascii 200),
    country: (string-ascii 50),
    region: (string-ascii 50),
    type: (string-ascii 50),
    established: uint,
    contact-email: (string-ascii 100),
    website: (string-ascii 200),
    status: uint,
    quality-score: uint,
    accreditation-date: (optional uint),
    last-assessment: uint,
    validator: (optional principal)
  }
)

;; Institution quality assessments
(define-map quality-assessments
  { institution-id: uint, assessment-id: uint }
  {
    assessor: principal,
    overall-score: uint,
    teaching-quality: uint,
    infrastructure: uint,
    research-output: uint,
    student-satisfaction: uint,
    assessment-date: uint,
    comments: (string-ascii 500),
    verified: bool
  }
)

;; Administrative permissions
(define-map administrators
  { admin: principal }
  {
    role: (string-ascii 50),
    permissions: uint,
    added-by: principal,
    added-at: uint,
    active: bool
  }
)

;; Institution validator registry
(define-map validators
  { validator: principal }
  {
    name: (string-ascii 100),
    specialization: (string-ascii 100),
    region: (string-ascii 50),
    validated-count: uint,
    approved-by: principal,
    active: bool
  }
)

;; Best practices registry
(define-map best-practices
  { practice-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    submitted-by: uint,
    effectiveness-score: uint,
    adoption-count: uint,
    created-at: uint,
    verified: bool
  }
)

;; Counter for generating unique IDs
(define-data-var next-institution-id uint u1)
(define-data-var next-standard-id uint u1)
(define-data-var next-assessment-id uint u1)
(define-data-var next-practice-id uint u1)

;; Register a new educational institution
(define-public (register-institution
    (name (string-ascii 200))
    (country (string-ascii 50))
    (region (string-ascii 50))
    (type (string-ascii 50))
    (established uint)
    (contact-email (string-ascii 100))
    (website (string-ascii 200))
  )
  (let
    (
      (institution-id (var-get next-institution-id))
    )
    (asserts! (> (len name) u0) ERR-INVALID-STATUS)
    (asserts! (> (len country) u0) ERR-INVALID-STATUS)
    (asserts! (> established u1800) ERR-INVALID-STATUS)
    
    (map-set institutions
      { institution-id: institution-id }
      {
        name: name,
        country: country,
        region: region,
        type: type,
        established: established,
        contact-email: contact-email,
        website: website,
        status: STATUS-PENDING,
        quality-score: u0,
        accreditation-date: none,
        last-assessment: block-height,
        validator: none
      }
    )
    
    (var-set next-institution-id (+ institution-id u1))
    (var-set total-institutions (+ (var-get total-institutions) u1))
    (ok institution-id)
  )
)

;; Create a new quality standard
(define-public (create-quality-standard
    (name (string-ascii 100))
    (description (string-ascii 500))
    (min-score uint)
    (category (string-ascii 50))
  )
  (let
    (
      (standard-id (var-get next-standard-id))
      (caller tx-sender)
    )
    (asserts! (is-admin-or-owner caller) ERR-UNAUTHORIZED)
    (asserts! (and (>= min-score MIN-QUALITY-SCORE) (<= min-score MAX-QUALITY-SCORE)) ERR-INVALID-SCORE)
    (asserts! (> (len name) u0) ERR-INVALID-STATUS)
    
    (map-set quality-standards
      { standard-id: standard-id }
      {
        name: name,
        description: description,
        version: (var-get standard-version),
        created-by: caller,
        created-at: block-height,
        status: u1,
        min-score: min-score,
        category: category
      }
    )
    
    (var-set next-standard-id (+ standard-id u1))
    (var-set total-standards (+ (var-get total-standards) u1))
    (ok standard-id)
  )
)

;; Conduct quality assessment for an institution
(define-public (assess-institution-quality
    (institution-id uint)
    (overall-score uint)
    (teaching-quality uint)
    (infrastructure uint)
    (research-output uint)
    (student-satisfaction uint)
    (comments (string-ascii 500))
  )
  (let
    (
      (assessment-id (var-get next-assessment-id))
      (caller tx-sender)
      (institution (unwrap! (map-get? institutions { institution-id: institution-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-validator caller) ERR-UNAUTHORIZED)
    (asserts! (and (>= overall-score MIN-QUALITY-SCORE) (<= overall-score MAX-QUALITY-SCORE)) ERR-INVALID-SCORE)
    (asserts! (<= teaching-quality MAX-QUALITY-SCORE) ERR-INVALID-SCORE)
    (asserts! (<= infrastructure MAX-QUALITY-SCORE) ERR-INVALID-SCORE)
    (asserts! (<= research-output MAX-QUALITY-SCORE) ERR-INVALID-SCORE)
    (asserts! (<= student-satisfaction MAX-QUALITY-SCORE) ERR-INVALID-SCORE)
    
    ;; Record the assessment
    (map-set quality-assessments
      { institution-id: institution-id, assessment-id: assessment-id }
      {
        assessor: caller,
        overall-score: overall-score,
        teaching-quality: teaching-quality,
        infrastructure: infrastructure,
        research-output: research-output,
        student-satisfaction: student-satisfaction,
        assessment-date: block-height,
        comments: comments,
        verified: false
      }
    )
    
    ;; Update institution with new quality score
    (map-set institutions
      { institution-id: institution-id }
      (merge institution {
        quality-score: overall-score,
        last-assessment: block-height,
        validator: (some caller)
      })
    )
    
    (var-set next-assessment-id (+ assessment-id u1))
    (ok assessment-id)
  )
)

;; Validate and approve an institution
(define-public (validate-institution (institution-id uint))
  (let
    (
      (caller tx-sender)
      (institution (unwrap! (map-get? institutions { institution-id: institution-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-admin-or-owner caller) ERR-UNAUTHORIZED)
    (asserts! (>= (get quality-score institution) MIN-QUALITY-SCORE) ERR-INVALID-SCORE)
    
    (map-set institutions
      { institution-id: institution-id }
      (merge institution {
        status: STATUS-VALIDATED
      })
    )
    (ok true)
  )
)

;; Grant accreditation to an institution
(define-public (grant-accreditation (institution-id uint))
  (let
    (
      (caller tx-sender)
      (institution (unwrap! (map-get? institutions { institution-id: institution-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-admin-or-owner caller) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status institution) STATUS-VALIDATED) ERR-INVALID-STATUS)
    (asserts! (>= (get quality-score institution) u80) ERR-INVALID-SCORE)
    
    (map-set institutions
      { institution-id: institution-id }
      (merge institution {
        status: STATUS-ACCREDITED,
        accreditation-date: (some block-height)
      })
    )
    (ok true)
  )
)

;; Add administrator
(define-public (add-administrator (admin principal) (role (string-ascii 50)) (permissions uint))
  (let
    (
      (caller tx-sender)
    )
    (asserts! (is-eq caller (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (> (len role) u0) ERR-INVALID-STATUS)
    
    (map-set administrators
      { admin: admin }
      {
        role: role,
        permissions: permissions,
        added-by: caller,
        added-at: block-height,
        active: true
      }
    )
    (ok true)
  )
)

;; Add validator
(define-public (add-validator
    (validator principal)
    (name (string-ascii 100))
    (specialization (string-ascii 100))
    (region (string-ascii 50))
  )
  (let
    (
      (caller tx-sender)
    )
    (asserts! (is-admin-or-owner caller) ERR-UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-STATUS)
    
    (map-set validators
      { validator: validator }
      {
        name: name,
        specialization: specialization,
        region: region,
        validated-count: u0,
        approved-by: caller,
        active: true
      }
    )
    (ok true)
  )
)

;; Submit best practice
(define-public (submit-best-practice
    (title (string-ascii 100))
    (description (string-ascii 500))
    (category (string-ascii 50))
    (institution-id uint)
  )
  (let
    (
      (practice-id (var-get next-practice-id))
      (institution (unwrap! (map-get? institutions { institution-id: institution-id }) ERR-NOT-FOUND))
    )
    (asserts! (>= (get status institution) STATUS-VALIDATED) ERR-UNAUTHORIZED)
    (asserts! (> (len title) u0) ERR-INVALID-STATUS)
    
    (map-set best-practices
      { practice-id: practice-id }
      {
        title: title,
        description: description,
        category: category,
        submitted-by: institution-id,
        effectiveness-score: u0,
        adoption-count: u0,
        created-at: block-height,
        verified: false
      }
    )
    
    (var-set next-practice-id (+ practice-id u1))
    (ok practice-id)
  )
)

;; Verify assessment
(define-public (verify-assessment (institution-id uint) (assessment-id uint))
  (let
    (
      (caller tx-sender)
      (assessment (unwrap! (map-get? quality-assessments { institution-id: institution-id, assessment-id: assessment-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-admin-or-owner caller) ERR-UNAUTHORIZED)
    (asserts! (not (get verified assessment)) ERR-ALREADY-EXISTS)
    
    (map-set quality-assessments
      { institution-id: institution-id, assessment-id: assessment-id }
      (merge assessment { verified: true })
    )
    (ok true)
  )
)

;; Update institution status
(define-public (update-institution-status (institution-id uint) (new-status uint))
  (let
    (
      (caller tx-sender)
      (institution (unwrap! (map-get? institutions { institution-id: institution-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-admin-or-owner caller) ERR-UNAUTHORIZED)
    (asserts! (or (is-eq new-status STATUS-PENDING)
                  (is-eq new-status STATUS-VALIDATED)
                  (is-eq new-status STATUS-ACCREDITED)
                  (is-eq new-status STATUS-SUSPENDED)) ERR-INVALID-STATUS)
    
    (map-set institutions
      { institution-id: institution-id }
      (merge institution { status: new-status })
    )
    (ok true)
  )
)

;; Read-only functions

;; Get institution details
(define-read-only (get-institution (institution-id uint))
  (map-get? institutions { institution-id: institution-id })
)

;; Get quality standard details
(define-read-only (get-quality-standard (standard-id uint))
  (map-get? quality-standards { standard-id: standard-id })
)

;; Get quality assessment details
(define-read-only (get-quality-assessment (institution-id uint) (assessment-id uint))
  (map-get? quality-assessments { institution-id: institution-id, assessment-id: assessment-id })
)

;; Get best practice details
(define-read-only (get-best-practice (practice-id uint))
  (map-get? best-practices { practice-id: practice-id })
)

;; Get system statistics
(define-read-only (get-system-stats)
  {
    total-institutions: (var-get total-institutions),
    total-standards: (var-get total-standards),
    standard-version: (var-get standard-version),
    contract-owner: (var-get contract-owner)
  }
)

;; Check if address is administrator
(define-read-only (is-administrator (address principal))
  (match (map-get? administrators { admin: address })
    admin-data (get active admin-data)
    false
  )
)

;; Check if address is validator
(define-read-only (is-validator (address principal))
  (match (map-get? validators { validator: address })
    validator-data (get active validator-data)
    false
  )
)

;; Get institution count by country
(define-read-only (get-institutions-by-status (status uint))
  (var-get total-institutions)
)

;; Get validator details
(define-read-only (get-validator (validator principal))
  (map-get? validators { validator: validator })
)

;; Private helper functions

;; Check if caller is admin or contract owner
(define-private (is-admin-or-owner (caller principal))
  (or (is-eq caller (var-get contract-owner))
      (is-administrator caller)
  )
)

;; Calculate weighted quality score
(define-private (calculate-weighted-score (teaching uint) (infrastructure uint) (research uint) (satisfaction uint))
  (/ (+ (* teaching u3) (* infrastructure u2) (* research u3) (* satisfaction u2)) u10)
)

;; Validate quality score range
(define-private (is-valid-score (score uint))
  (and (>= score u0) (<= score MAX-QUALITY-SCORE))
)

