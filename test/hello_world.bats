@test "hello world test" {
  run echo "Hello, World!"
  [ "$status" -eq 0 ]
  [ "$output" = "Hello, World!" ]
}