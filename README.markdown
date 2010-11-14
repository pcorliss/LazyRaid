LazyRaid
========

LazyRaid is a program to provide redundancy for a group of disks. The main difference between LazyRaid and an actual RAID array is that individual disks are portable and treated as independent. But in the case of a disk failure all disks can be reconnected to recover deleted files. Additionally if a file is accidentally deleted it can be recovered.

Installation
------------

LazyRaid uses a custome C library extension to overcome some speed issues with Ruby's XOR calculation. You'll need to compile it for your OS.

    cd lib/xor
    make

Options
-------

    Usage: run [options]

    -v, --version                    Print Version Information
    -h, --help                       Show this message`
    -i, --init-disk [MOUNTDIR]       Initialize a mounted disk
    -e, --enumerate                  Get a list of all files on all attached disks and store their contents and checksums.
    -a, --dead                       Mark a disk as dead
    -r, --recover [FILE]             Recover a file
    -R, --recover-all                Recover all files for a specific disk
    -p, --gen-parity                 Generate Parity Bits for all attached disks
    -f, --folder [FOLDER]            Specify a folder to save recovered files to
    -d, --disk [DISKID]              Specify a disk to perform an action on
    -c, --check                      Check the consistency of the files on a specific disk
    -C, --recover-inconsistent       Recover all inconsistent files on a specific disk`


Requirements
------------

Depends on Ruby 1.9 (possibly even 1.9.2)

License
-------

LazyRaid is licensed under the GPL. See the LICENSE file for details.

Contact
-------

LazyRaid was created by Philip Corliss (pcorliss@50projects.com) as part of 50projects.com. You can find more information on him and 50projects at http://blog.50projects.com 
