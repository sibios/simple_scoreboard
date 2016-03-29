simple_scoreboard
=================

It's not so simple anymore...  To better facilitate jeopardy-style CTFs the UI has been completely re-designed.  Authentication was added to allow for in game administration (toggle challenges, lock-out unruly teams, etc...).

How to deploy?
--------------

1. `git clone https://github.com/sibios/simple_scoreboard.git`
2. Create a conf/flags.yml (use the example file as a starting point)
3. Update admin_password in conf/config.yml to something more difficult to guess
4. `rackup`
5. Play!


TODO
----

- Enable more straight-forward customization of the system
	- CTF title
	- Byline
	- Subtitle
	- Category count
