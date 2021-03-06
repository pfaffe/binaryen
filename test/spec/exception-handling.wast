(module
  (event $e-v (attr 0))
  (event $e-i32 (attr 0) (param i32))
  (event $e-f32 (attr 0) (param f32))
  (event $e-i32-f32 (attr 0) (param i32 f32))

  (func $throw_single_value (export "throw_single_value")
    (throw $e-i32 (i32.const 5))
  )

  (func (export "throw_multiple_values")
    (throw $e-i32-f32 (i32.const 3) (f32.const 3.5))
  )

  (func (export "try_nothrow") (result i32)
    (try (result i32)
      (do
        (i32.const 3)
      )
      (catch $e-i32
        (drop (pop i32))
        (i32.const 0)
      )
    )
  )

  (func (export "try_throw_catch") (result i32)
    (try (result i32)
      (do
        (throw $e-i32 (i32.const 5))
      )
      (catch $e-i32
        (drop (pop i32))
        (i32.const 3)
      )
    )
  )

  (func (export "try_throw_nocatch") (result i32)
    (try (result i32)
      (do
        (throw $e-i32 (i32.const 5))
      )
      (catch $e-f32
        (drop (pop f32))
        (i32.const 3)
      )
    )
  )

  (func (export "try_throw_catchall") (result i32)
    (try (result i32)
      (do
        (throw $e-i32 (i32.const 5))
      )
      (catch $e-f32
        (drop (pop f32))
        (i32.const 4)
      )
      (catch_all
        (i32.const 3)
      )
    )
  )

  (func (export "try_call_catch") (result i32)
    (try (result i32)
      (do
        (call $throw_single_value)
        (unreachable)
      )
      (catch $e-i32
        (pop i32)
      )
    )
  )

  (func (export "try_throw_multivalue_catch") (result i32) (local $x (i32 f32))
    (try (result i32)
      (do
        (throw $e-i32-f32 (i32.const 5) (f32.const 1.5))
      )
      (catch $e-i32-f32
        (local.set $x
          (pop i32 f32)
        )
        (tuple.extract 0
          (local.get $x)
        )
      )
    )
  )

  (func (export "try_throw_rethrow")
    (try
      (do
        (throw $e-i32 (i32.const 5))
      )
      (catch $e-i32
        (drop (pop i32))
        (rethrow 0)
      )
    )
  )

  (func (export "try_call_rethrow")
    (try
      (do
        (call $throw_single_value)
      )
      (catch_all
        (rethrow 0)
      )
    )
  )

  (func (export "rethrow_depth_test1") (result i32)
    (try (result i32)
      (do
        (try
          (do
            (throw $e-i32 (i32.const 1))
          )
          (catch_all
            (try
              (do
                (throw $e-i32 (i32.const 2))
              )
              (catch $e-i32
                (drop (pop i32))
                (rethrow 0) ;; rethrow (i32.const 2)
              )
            )
          )
        )
      )
      (catch $e-i32
        (pop i32) ;; result is (i32.const 2)
      )
    )
  )

  ;; Can we handle rethrows with the depth > 0?
  (func (export "rethrow_depth_test2") (result i32)
    (try (result i32)
      (do
        (try
          (do
            (throw $e-i32 (i32.const 1))
          )
          (catch_all
            (try
              (do
                (throw $e-i32 (i32.const 2))
              )
              (catch $e-i32
                (drop (pop i32))
                (rethrow 1) ;; rethrow (i32.const 1)
              )
            )
          )
        )
      )
      (catch $e-i32
        (pop i32) ;; result is (i32.const 1)
      )
    )
  )

  ;; Tests whether the exception stack is managed correctly after rethrows
  (func (export "rethrow_depth_test3") (result i32)
    (try (result i32)
      (do
        (try
          (do
            (try
              (do
                (throw $e-i32 (i32.const 1))
              )
              (catch_all
                (try
                  (do
                    (throw $e-i32 (i32.const 2))
                  )
                  (catch $e-i32
                    (drop (pop i32))
                    (rethrow 1) ;; rethrow (i32.const 1)
                  )
                )
              )
            )
          )
          (catch $e-i32
            (rethrow 0) ;; rethrow (i32.const 1) again
          )
        )
      )
      (catch $e-i32
        (pop i32) ;; result is (i32.const 1)
      )
    )
  )
)

(assert_trap (invoke "throw_single_value"))
(assert_trap (invoke "throw_multiple_values"))
(assert_return (invoke "try_nothrow") (i32.const 3))
(assert_return (invoke "try_throw_catch") (i32.const 3))
(assert_trap (invoke "try_throw_nocatch"))
(assert_return (invoke "try_throw_catchall") (i32.const 3))
(assert_return (invoke "try_call_catch") (i32.const 5))
(assert_return (invoke "try_throw_multivalue_catch") (i32.const 5))
(assert_trap (invoke "try_throw_rethrow"))
(assert_trap (invoke "try_call_rethrow"))
(assert_return (invoke "rethrow_depth_test1") (i32.const 2))
(assert_return (invoke "rethrow_depth_test2") (i32.const 1))
(assert_return (invoke "rethrow_depth_test3") (i32.const 1))

(assert_invalid
  (module
    (func $f0
      (try
        (do (nop))
        (catch $e-i32
          (pop i32)
        )
      )
    )
  )
  "try's body type must match catch's body type"
)

(assert_invalid
  (module
    (func $f0
      (try
        (do (i32.const 0))
        (catch $e-i32
          (pop i32)
        )
      )
    )
  )
   "try's type does not match try body's type"
)

(assert_invalid
  (module
    (event $e-i32 (attr 0) (param i32))
    (func $f0
      (throw $e-i32 (f32.const 0))
    )
  )
  "event param types must match"
)

(assert_invalid
  (module
    (event $e-i32 (attr 0) (param i32 f32))
    (func $f0
      (throw $e-i32 (f32.const 0))
    )
  )
  "event's param numbers must match"
)
