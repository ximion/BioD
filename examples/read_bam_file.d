/*
   To run this example from this directory:
   rdmd -I.. read_bam_file.d

// compile this example with

// debug version
dmd -i -I.. read_bam_file.d

// optimised version
dmd -i -O -release -inline -boundscheck=off -I.. read_bam_file.d

*/

import bio.std.hts.bam.reader;
import bio.std.hts.bam.pileup;
import std.stdio;

void main() {

    auto bam = new BamReader("../test/data/ex1_header.bam");
    auto reads = bam["chr2"][150 .. 160]; // region chr2:149-158
    auto pileup = makePileup(reads,
            false,     // reads don't contain MD tags
            155, 158); // specify [start, end) interval

    foreach (column; pileup) {
        writeln("Reference position: ", column.position);
        writeln("    Coverage: ", column.coverage);
        writeln("    Reads:");

        foreach (read; column.reads) {
            writefln("%30s\t%s\t%.2d\t%s\t%2s/%2s\t%2s/%2s\t%10s\t%s %s", 
                    read.name, 
                    read.current_base,
                    read.current_base_quality,
                    read.cigar_operation,
                    read.cigar_operation_offset + 1, read.cigar_operation.length,
                    read.query_offset + 1, read.sequence.length,
                    read.cigarString(),
                    read.cigar_before, read.cigar_after);
        }
    }
}
