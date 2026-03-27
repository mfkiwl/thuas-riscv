# srec2mif

This is a self made program that converts a Motorola S-record file
to a MIF file suitable for inclusion in a memory megafunction..

```
srec2mif v0.1 -- an S-record to MIF table converter
Usage: srec2mif [-vqbhwd] inputfile [outputfile]
   -v        Verbose
   -q        Quiet. Only errors are reported
   -b        Byte output (default)
   -h        Halfword output (16 bits, Little Endian)
   -w        Word output (32 bits, Little Endian)
   -d        Double word output (64 bits, Little Endian)
If outputfile is omitted, stdout is used
Program size must be less then 10 MB

The address of the first record is used as an offset
so that the first record starts at address 0.
```

The address of the first record is used as an offset
so that the first record starts at address 0.

## Status

Works.
