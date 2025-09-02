
;; title: student-mobility
;; version: 1.0.0
;; summary: Global Student Mobility and Credit Transfer Contract
;; description: Manages cross-border academic credit recognition, student records, and mobility tracking

;; Constants for error handling
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-ALREADY-EXISTS (err u201))
(define-constant ERR-NOT-FOUND (err u202))
(define-constant ERR-INVALID-CREDITS (err u203))
(define-constant ERR-INVALID-STATUS (err u204))
(define-constant ERR-TRANSFER-FAILED (err u205))
(define-constant ERR-INVALID-GPA (err u206))

;; Contract administrative variables
(define-data-var contract-owner principal tx-sender)
(define-data-var total-students uint u0)
(define-data-var total-transfers uint u0)
(define-data-var total-agreements uint u0)

;; Credit and GPA constants
(define-constant MIN-CREDITS u1)
(define-constant MAX-CREDITS u300)
(define-constant MIN-GPA u0)
(define-constant MAX-GPA u400) ;; GPA * 100 for precision (4.00 = 400)

;; Transfer status constants
(define-constant TRANSFER-PENDING u1)
(define-constant TRANSFER-APPROVED u2)
(define-constant TRANSFER-REJECTED u3)
(define-constant TRANSFER-COMPLETED u4)

;; Student status constants
(define-constant STUDENT-ACTIVE u1)
(define-constant STUDENT-GRADUATED u2)
(define-constant STUDENT-SUSPENDED u3)
(define-constant STUDENT-TRANSFERRED u4)

;; Student registry with academic records
(define-map students
  { student-id: uint }
  {
    first-name: (string-ascii 100),
    last-name: (string-ascii 100),
    email: (string-ascii 100),
    passport-number: (string-ascii 50),
    nationality: (string-ascii 50),
    date-of-birth: uint,
    home-institution: uint,
    current-institution: uint,
    total-credits: uint,
    cumulative-gpa: uint,
    enrollment-date: uint,
    status: uint,
    verified: bool
  }
)

;; Academic transcript records
(define-map transcripts
  { student-id: uint, record-id: uint }
  {
    institution-id: uint,
    course-code: (string-ascii 20),
    course-name: (string-ascii 100),
    credits: uint,
    grade: (string-ascii 5),
    grade-points: uint,
    semester: (string-ascii 20),
    academic-year: uint,
    verified: bool,
    verifier: (optional principal)
  }
)

;; Credit transfer requests
(define-map credit-transfers
  { transfer-id: uint }
  {
    student-id: uint,
    from-institution: uint,
    to-institution: uint,
    course-code: (string-ascii 20),
    course-name: (string-ascii 100),
    original-credits: uint,
    transferred-credits: uint,
    equivalency-score: uint,
    transfer-date: uint,
    status: uint,
    approved-by: (optional principal),
    notes: (string-ascii 300)
  }
)

;; Mutual recognition agreements between institutions
(define-map recognition-agreements
  { agreement-id: uint }
  {
    institution-a: uint,
    institution-b: uint,
    agreement-type: (string-ascii 50),
    credit-transfer-rate: uint,
    effective-date: uint,
    expiry-date: uint,
    signed-by-a: principal,
    signed-by-b: principal,
    active: bool
  }
)

;; Student mobility records
(define-map mobility-records
  { student-id: uint, mobility-id: uint }
  {
    from-institution: uint,
    to-institution: uint,
    program-type: (string-ascii 50),
    start-date: uint,
    end-date: uint,
    credits-earned: uint,
    status: uint,
    exchange-coordinator: (optional principal)
  }
)

;; Institution representatives authorized to verify records
(define-map institution-representatives
  { representative: principal }
  {
    institution-id: uint,
    name: (string-ascii 100),
    title: (string-ascii 100),
    email: (string-ascii 100),
    permissions: uint,
    added-by: principal,
    active: bool
  }
)

;; Course equivalency mappings
(define-map course-equivalencies
  { equivalency-id: uint }
  {
    source-institution: uint,
    target-institution: uint,
    source-course: (string-ascii 20),
    target-course: (string-ascii 20),
    credit-ratio: uint,
    verified-by: principal,
    created-at: uint,
    active: bool
  }
)

;; Counter variables for unique ID generation
(define-data-var next-student-id uint u1)
(define-data-var next-transfer-id uint u1)
(define-data-var next-record-id uint u1)
(define-data-var next-agreement-id uint u1)
(define-data-var next-mobility-id uint u1)
(define-data-var next-equivalency-id uint u1)

;; Register a new student
(define-public (register-student
    (first-name (string-ascii 100))
    (last-name (string-ascii 100))
    (email (string-ascii 100))
    (passport-number (string-ascii 50))
    (nationality (string-ascii 50))
    (date-of-birth uint)
    (home-institution uint)
  )
  (let
    (
      (student-id (var-get next-student-id))
    )
    (asserts! (> (len first-name) u0) ERR-INVALID-STATUS)
    (asserts! (> (len last-name) u0) ERR-INVALID-STATUS)
    (asserts! (> (len email) u0) ERR-INVALID-STATUS)
    (asserts! (> (len passport-number) u0) ERR-INVALID-STATUS)
    
    (map-set students
      { student-id: student-id }
      {
        first-name: first-name,
        last-name: last-name,
        email: email,
        passport-number: passport-number,
        nationality: nationality,
        date-of-birth: date-of-birth,
        home-institution: home-institution,
        current-institution: home-institution,
        total-credits: u0,
        cumulative-gpa: u0,
        enrollment-date: block-height,
        status: STUDENT-ACTIVE,
        verified: false
      }
    )
    
    (var-set next-student-id (+ student-id u1))
    (var-set total-students (+ (var-get total-students) u1))
    (ok student-id)
  )
)

;; Add academic record to transcript
(define-public (add-transcript-record
    (student-id uint)
    (institution-id uint)
    (course-code (string-ascii 20))
    (course-name (string-ascii 100))
    (credits uint)
    (grade (string-ascii 5))
    (grade-points uint)
    (semester (string-ascii 20))
    (academic-year uint)
  )
  (let
    (
      (record-id (var-get next-record-id))
      (caller tx-sender)
      (student (unwrap! (map-get? students { student-id: student-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-institution-representative caller institution-id) ERR-UNAUTHORIZED)
    (asserts! (and (>= credits MIN-CREDITS) (<= credits u20)) ERR-INVALID-CREDITS)
    (asserts! (<= grade-points MAX-GPA) ERR-INVALID-GPA)
    (asserts! (> (len course-code) u0) ERR-INVALID-STATUS)
    
    (map-set transcripts
      { student-id: student-id, record-id: record-id }
      {
        institution-id: institution-id,
        course-code: course-code,
        course-name: course-name,
        credits: credits,
        grade: grade,
        grade-points: grade-points,
        semester: semester,
        academic-year: academic-year,
        verified: false,
        verifier: none
      }
    )
    
    ;; Update student total credits
    (map-set students
      { student-id: student-id }
      (merge student {
        total-credits: (+ (get total-credits student) credits)
      })
    )
    
    (var-set next-record-id (+ record-id u1))
    (ok record-id)
  )
)

;; Request credit transfer
(define-public (request-credit-transfer
    (student-id uint)
    (from-institution uint)
    (to-institution uint)
    (course-code (string-ascii 20))
    (course-name (string-ascii 100))
    (original-credits uint)
    (notes (string-ascii 300))
  )
  (let
    (
      (transfer-id (var-get next-transfer-id))
      (caller tx-sender)
      (student (unwrap! (map-get? students { student-id: student-id }) ERR-NOT-FOUND))
    )
    (asserts! (or (is-institution-representative caller from-institution)
                  (is-institution-representative caller to-institution)) ERR-UNAUTHORIZED)
    (asserts! (and (>= original-credits MIN-CREDITS) (<= original-credits u20)) ERR-INVALID-CREDITS)
    
    ;; Calculate transferred credits based on agreement
    (let
      (
        (transfer-rate (get-transfer-rate from-institution to-institution))
        (transferred-credits (/ (* original-credits transfer-rate) u100))
      )
      
      (map-set credit-transfers
        { transfer-id: transfer-id }
        {
          student-id: student-id,
          from-institution: from-institution,
          to-institution: to-institution,
          course-code: course-code,
          course-name: course-name,
          original-credits: original-credits,
          transferred-credits: transferred-credits,
          equivalency-score: transfer-rate,
          transfer-date: block-height,
          status: TRANSFER-PENDING,
          approved-by: none,
          notes: notes
        }
      )
      
      (var-set next-transfer-id (+ transfer-id u1))
      (var-set total-transfers (+ (var-get total-transfers) u1))
      (ok transfer-id)
    )
  )
)

;; Approve credit transfer
(define-public (approve-credit-transfer (transfer-id uint))
  (let
    (
      (caller tx-sender)
      (transfer (unwrap! (map-get? credit-transfers { transfer-id: transfer-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-institution-representative caller (get to-institution transfer)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status transfer) TRANSFER-PENDING) ERR-INVALID-STATUS)
    
    (map-set credit-transfers
      { transfer-id: transfer-id }
      (merge transfer {
        status: TRANSFER-APPROVED,
        approved-by: (some caller)
      })
    )
    (ok true)
  )
)

;; Create mutual recognition agreement
(define-public (create-recognition-agreement
    (institution-a uint)
    (institution-b uint)
    (agreement-type (string-ascii 50))
    (credit-transfer-rate uint)
    (duration-blocks uint)
  )
  (let
    (
      (agreement-id (var-get next-agreement-id))
      (caller tx-sender)
    )
    (asserts! (or (is-institution-representative caller institution-a)
                  (is-institution-representative caller institution-b)) ERR-UNAUTHORIZED)
    (asserts! (and (>= credit-transfer-rate u50) (<= credit-transfer-rate u100)) ERR-INVALID-CREDITS)
    (asserts! (> duration-blocks u0) ERR-INVALID-STATUS)
    
    (map-set recognition-agreements
      { agreement-id: agreement-id }
      {
        institution-a: institution-a,
        institution-b: institution-b,
        agreement-type: agreement-type,
        credit-transfer-rate: credit-transfer-rate,
        effective-date: block-height,
        expiry-date: (+ block-height duration-blocks),
        signed-by-a: caller,
        signed-by-b: caller,
        active: true
      }
    )
    
    (var-set next-agreement-id (+ agreement-id u1))
    (var-set total-agreements (+ (var-get total-agreements) u1))
    (ok agreement-id)
  )
)

;; Record student mobility
(define-public (record-student-mobility
    (student-id uint)
    (to-institution uint)
    (program-type (string-ascii 50))
    (expected-duration uint)
  )
  (let
    (
      (mobility-id (var-get next-mobility-id))
      (caller tx-sender)
      (student (unwrap! (map-get? students { student-id: student-id }) ERR-NOT-FOUND))
    )
    (asserts! (or (is-institution-representative caller (get current-institution student))
                  (is-institution-representative caller to-institution)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status student) STUDENT-ACTIVE) ERR-INVALID-STATUS)
    
    (map-set mobility-records
      { student-id: student-id, mobility-id: mobility-id }
      {
        from-institution: (get current-institution student),
        to-institution: to-institution,
        program-type: program-type,
        start-date: block-height,
        end-date: (+ block-height expected-duration),
        credits-earned: u0,
        status: STUDENT-ACTIVE,
        exchange-coordinator: (some caller)
      }
    )
    
    ;; Update student current institution
    (map-set students
      { student-id: student-id }
      (merge student {
        current-institution: to-institution,
        status: STUDENT-TRANSFERRED
      })
    )
    
    (var-set next-mobility-id (+ mobility-id u1))
    (ok mobility-id)
  )
)

;; Verify transcript record
(define-public (verify-transcript-record (student-id uint) (record-id uint))
  (let
    (
      (caller tx-sender)
      (transcript (unwrap! (map-get? transcripts { student-id: student-id, record-id: record-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-institution-representative caller (get institution-id transcript)) ERR-UNAUTHORIZED)
    (asserts! (not (get verified transcript)) ERR-ALREADY-EXISTS)
    
    (map-set transcripts
      { student-id: student-id, record-id: record-id }
      (merge transcript {
        verified: true,
        verifier: (some caller)
      })
    )
    (ok true)
  )
)

;; Add institution representative
(define-public (add-institution-representative
    (representative principal)
    (institution-id uint)
    (name (string-ascii 100))
    (title (string-ascii 100))
    (email (string-ascii 100))
    (permissions uint)
  )
  (let
    (
      (caller tx-sender)
    )
    (asserts! (is-eq caller (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-STATUS)
    
    (map-set institution-representatives
      { representative: representative }
      {
        institution-id: institution-id,
        name: name,
        title: title,
        email: email,
        permissions: permissions,
        added-by: caller,
        active: true
      }
    )
    (ok true)
  )
)

;; Create course equivalency mapping
(define-public (create-course-equivalency
    (source-institution uint)
    (target-institution uint)
    (source-course (string-ascii 20))
    (target-course (string-ascii 20))
    (credit-ratio uint)
  )
  (let
    (
      (equivalency-id (var-get next-equivalency-id))
      (caller tx-sender)
    )
    (asserts! (or (is-institution-representative caller source-institution)
                  (is-institution-representative caller target-institution)) ERR-UNAUTHORIZED)
    (asserts! (and (>= credit-ratio u50) (<= credit-ratio u150)) ERR-INVALID-CREDITS)
    
    (map-set course-equivalencies
      { equivalency-id: equivalency-id }
      {
        source-institution: source-institution,
        target-institution: target-institution,
        source-course: source-course,
        target-course: target-course,
        credit-ratio: credit-ratio,
        verified-by: caller,
        created-at: block-height,
        active: true
      }
    )
    
    (var-set next-equivalency-id (+ equivalency-id u1))
    (ok equivalency-id)
  )
)

;; Update student GPA
(define-public (update-student-gpa (student-id uint) (new-gpa uint))
  (let
    (
      (caller tx-sender)
      (student (unwrap! (map-get? students { student-id: student-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-institution-representative caller (get current-institution student)) ERR-UNAUTHORIZED)
    (asserts! (<= new-gpa MAX-GPA) ERR-INVALID-GPA)
    
    (map-set students
      { student-id: student-id }
      (merge student {
        cumulative-gpa: new-gpa
      })
    )
    (ok true)
  )
)

;; Read-only functions

;; Get student details
(define-read-only (get-student (student-id uint))
  (map-get? students { student-id: student-id })
)

;; Get transcript record
(define-read-only (get-transcript-record (student-id uint) (record-id uint))
  (map-get? transcripts { student-id: student-id, record-id: record-id })
)

;; Get credit transfer details
(define-read-only (get-credit-transfer (transfer-id uint))
  (map-get? credit-transfers { transfer-id: transfer-id })
)

;; Get recognition agreement
(define-read-only (get-recognition-agreement (agreement-id uint))
  (map-get? recognition-agreements { agreement-id: agreement-id })
)

;; Get mobility record
(define-read-only (get-mobility-record (student-id uint) (mobility-id uint))
  (map-get? mobility-records { student-id: student-id, mobility-id: mobility-id })
)

;; Get course equivalency
(define-read-only (get-course-equivalency (equivalency-id uint))
  (map-get? course-equivalencies { equivalency-id: equivalency-id })
)

;; Get system statistics
(define-read-only (get-mobility-stats)
  {
    total-students: (var-get total-students),
    total-transfers: (var-get total-transfers),
    total-agreements: (var-get total-agreements),
    contract-owner: (var-get contract-owner)
  }
)

;; Check if address is institution representative
(define-read-only (is-institution-representative (address principal) (institution-id uint))
  (match (map-get? institution-representatives { representative: address })
    rep-data (and (get active rep-data) (is-eq (get institution-id rep-data) institution-id))
    false
  )
)

;; Get transfer rate between institutions
(define-read-only (get-transfer-rate (from-institution uint) (to-institution uint))
  (match (map-get? recognition-agreements { agreement-id: u1 })
    agreement (get credit-transfer-rate agreement)
    u75
  )
)

;; Verify student identity
(define-read-only (verify-student-identity (student-id uint) (passport-number (string-ascii 50)))
  (match (map-get? students { student-id: student-id })
    student-data (is-eq (get passport-number student-data) passport-number)
    false
  )
)

;; Get student transcript summary
(define-read-only (get-transcript-summary (student-id uint))
  (match (map-get? students { student-id: student-id })
    student-data (some {
      total-credits: (get total-credits student-data),
      cumulative-gpa: (get cumulative-gpa student-data),
      status: (get status student-data),
      verified: (get verified student-data)
    })
    none
  )
)

;; Private helper functions

;; Check if caller is contract owner
(define-private (is-contract-owner (caller principal))
  (is-eq caller (var-get contract-owner))
)

;; Calculate credit equivalency
(define-private (calculate-credit-equivalency (original-credits uint) (transfer-rate uint))
  (/ (* original-credits transfer-rate) u100)
)

;; Validate GPA calculation
(define-private (is-valid-gpa (gpa uint))
  (and (>= gpa MIN-GPA) (<= gpa MAX-GPA))
)

