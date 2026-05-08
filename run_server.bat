@echo off
set PATH=%USERPROFILE%\scoop\apps\elixir\current\bin;%USERPROFILE%\scoop\apps\erlang\current\bin;%USERPROFILE%\scoop\apps\mingw\current\bin;C:\Program Files\Git\cmd;%PATH%
set MAKE=make
cd /d C:\Dev\001New\project-galaxy
mix phx.server
