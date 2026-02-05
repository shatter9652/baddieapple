# baddieapple writeup
In early June, 2025, a friend and I decided to dive into finding a way to get arbitrary code execution (ACE) on a keyrolled device.

We discovered that oobescape set crossystem & vpd to have `block_devmode` to 0, allowing for [dededeicarus](https://github.com/HarryJarry1/dededeicarus) (a project I released around this time) and other dev mode recovery image code execution via unverified [BadRecovery](https://github.com/BinBashBanana/badrecovery). (same concept worked with sh1ttyOOBE, allowing for [badbr0ker](https://github.com/crosbreaker/badbr0ker), however sh1ttyOOBE wasnt public at this time.)

Then, we started thinking about how miniOS versions were stored, and realized that even on 136 (latest at the time), you could still use BadApple if an old version of miniOS was still stored in miniOS-B.


This led to the realization that recovery didn't check miniOS before copying it to the internal disk, meaning as long as it is signed, the Chromebook does not care what version it is.  
So, we asked [BinBashBanana](https://github.com/BinBashBanana) to help with the commands, saw our concept worked, reported it to Google, then made the repository public!
