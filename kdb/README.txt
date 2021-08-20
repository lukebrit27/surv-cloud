Welcome to the kdb+ 32bit Edition.

There is a Google discussion group for users of this edition of kdb+ at http://groups.google.com/group/personal-kdbplus. If you have questions, please post there.

kdb+ is Kx Systems flagship product: a unified platform for real-time and historical databases, event processing and general data-oriented programming. This release is a full version of kdb+ but is limited to a 32-bit address space. To upgrade to our production 64-bit software please contact sales@kx.com for information.

To use this software you must have read and agreed to the license at http://kx.com/license2.php.

To install this software:

* When unzipping the install, take care to retain the embedded folder structure.

- On Windows, unzip to c:\q and then open a command prompt window, change directory to c:\q, and run c:\q\w32\q.

- On Linux, Solaris and macOS, unzip in ~/q, change directory to ~/q, and run ~/q/{l32|s32|v32|m32}/q as appropriate. The respective versions are:
	. l32 is Linux on x86
	. s32 is Solaris 10 or higher on Sparc
	. v32 is Solaris 10 or higher on x86
	. m32 is MacOSX 10.10 or higher on x86

e.g. on Linux, run ~/q/l32/q

- RaspberryPi users, please note that additional libraries for the Pi are available at http://kx.com/q/e/raspberrypi.zip

When running the trial on Linux 64-bit systems, you may need to
install the package ia32-libs. Depending on your distribution, usually this
can be installed with one of the commands:

 sudo apt-get install ia32-libs

or

 yum install ia32-libs

or

 yum install libstdc++.i686 zlib.i686

or

 sudo apt-get install gcc-multilib

When upgrading from a previous release, please note that the q binary file must match the q.k file, so if you choose to install to a directory different to the above defaults, please set the QHOME environment variable to point to the directory where you have installed the updated q.k file.

Note that command line history can be obtained on the Unix versions through the use of the package "rlwrap" which can be found at http://freshmeat.net/projects/rlwrap. On Linux, depending on your distribution, this can be installed with the command:

 sudo apt-get install rlwrap
or
 yum install rlwrap

For macOS users, rlwrap can be installed through the use of http://wiki.github.com/mxcl/homebrew/Installation with the command:

 brew install rlwrap

To learn to use this software please visit our community site at http://code.kx.com.

Good starting points are:

Tutorial introductions to the q language and kdb+ database:
http://code.kx.com/q

A cookbook of common tasks:
http://code.kx.com/q/cookbook/introduction

A reference on the built-in functions:
http://code.kx.com/q/ref/card

GitHub hosts a wide range of user-contributed kdb+ repositories. 
Kx indexes most of them:
https://kxsystems.github.io

Also interfaces to other languages, processes and editor integrations:
http://code.kx.com/q/interfaces

In particular, for Excel integration, see:
http://code.kx.com/q/interfaces/excel-client-for-q/

A book on kdb+ is available from Amazon. The title is "Q for Mortals" by Jeffry Borror, now in its 3rd edition, which is also available online:
http://code.kx.com/q4m3

We hope you enjoy this release, and welcome to the kdb+ community!

	The Kx Systems team.

