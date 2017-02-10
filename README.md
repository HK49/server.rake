#### simple task to launch guard with puma and postgres
---
### Usage:

#### guard tasks:
1. `rake guard:start`  
   launches Postgres Service if it wasn't active  
   connects Active Support if connection was dead  
   invokes Guard  
   if exited by Ctrl+C doesn't show all stack trace because of trap on INT signal  
   can be launched with options like so:  
 - `rake guard:start -- -h` will show all available options and exit task  
 - `rake --trace guard -- -h` to run the above but with trace
2. `rake guard:restart` restarts guard, puma and postgres (don't see any actual usage for this)  
3. `rake guard` is shortcut for `rake guard:start`. can also be called with options in the same way.

#### puma tasks  
4. `rake puma:start`  
   launches Postgres Service if it wasn't active  
   connects Active Support if connection was dead  
   launches Puma Server  
   if exited by Ctrl+C doesn't show all stack trace because of trap on INT signal  
5. `rake puma:kill` terminates any puma instances on tcp:8080 (port should be changed corresponding to config)  
6. `rake puma:overkill` kills anything on tcp:8080 (port should be changed corresponding to config)  
7. `rake puma` corresponding to input will execute `rake guard:start` or `rake puma:start`. can pass options to guard.  

#### postgres tasks  
8. `rake psql:start`  
   launches Postgres Service if it wasn't active  
   connects Active Support if connection was dead  
9. `rake psql:connect` connects Active Support if connection was dead  
10. `rake psql:restart` restarts Postgres Service
11. `rake psql:stop` stops Postgres Service
