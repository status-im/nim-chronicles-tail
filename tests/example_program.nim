import
  chronicles, random, os

let sources = ["Alice", "Bob", "George", "John", "Jane"]

while true:
  let delay = 100 + rand(100)
  sleep(delay)
  
  let action = delay mod 10
  if action < 5:
    info "Received incoming packet", size = delay, source = sources[action]
  elif action < 9:
    debug "Re-indexing database", time = delay
  else:
    warn "Connection lost"

