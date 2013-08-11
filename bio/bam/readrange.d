/*
    This file is part of BioD.
    Copyright (C) 2012    Artem Tarasov <lomereiter@gmail.com>

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.

*/
module bio.bam.readrange;

import bio.bam.read;
import bio.bam.abstractreader;
import bio.bam.reader;
import bio.core.bgzf.inputstream;
import bio.core.bgzf.virtualoffset;
import bio.core.utils.switchendianness;

import std.stream;
import std.algorithm;
import std.system;
debug import std.stdio;

/// Read + its start/end virtual offsets
struct BamReadBlock {
    VirtualOffset start_virtual_offset; ///
    VirtualOffset end_virtual_offset; ///
    BamRead read; ///
    alias read this; ///

    ///
    BamReadBlock dup() @property const {
        return BamReadBlock(start_virtual_offset, end_virtual_offset, read.dup);
    }
}

///
mixin template withOffsets() {
    /**
        Returns: virtual offsets of beginning and end of the current read
                 plus the current read itself.
     */
    BamReadBlock front() @property {
        return BamReadBlock(_start_voffset, 
                            _stream.virtualTell(),
                            _current_record);
    }

    private VirtualOffset _start_voffset;

    private void beforeNextBamReadLoad() {
        _start_voffset = _stream.virtualTell();
    }
}

///
mixin template withoutOffsets() {
    /**
        Returns: current read
     */
    ref BamRead front() @property {
        return _current_record;
    }

    private void beforeNextBamReadLoad() {}
}

/// $(D front) return type is determined by $(I IteratePolicy)
struct BamReadRange(alias IteratePolicy) 
{ 

    /// Create new range from IChunkInputStream.
    this(IChunkInputStream stream, BamReader reader=null) {
        _stream = stream;
        _reader = reader;
        readNext();
    }

    ///
    bool empty() @property const {
        return _empty;
    }

    mixin IteratePolicy;
   
    ///
    void popFront() {
        readNext();
    }

private:
    IChunkInputStream _stream;

    BamReader _reader;

    BamRead _current_record;
    bool _empty = false;

    /*
      Reads next bamRead block from stream.
     */
    void readNext() {

        // In fact, on BAM files containing a special EOF BGZF block
        // this condition will be always false!
        //
        // The reason is that we don't want to unpack next block just
        // in order to see if it's an EOF one or not.
        if (_stream.eof()) {
            _empty = true;
            return;
        }
     
        // In order to get the right virtual offset, we need to do it here.
        beforeNextBamReadLoad();

        // debug { stderr.writeln("[debug][BamReadRange] getting block size..."); }
        // Here's where _empty is really set!
        int block_size = void;
        ubyte* ptr = cast(ubyte*)(&block_size);
        auto _read = 0;
        while (_read < int.sizeof) {
            auto _actually_read = _stream.readBlock(ptr, int.sizeof - _read);
            // debug {
            //     stderr.writeln("[debug][BamReadRange] read ", _actually_read, " bytes");
            // }
            if (_actually_read == 0) {
                debug stderr.writeln("[debug][BamReadRange] empty!");
                _empty = true;
                return;
            }
            _read += _actually_read;
            ptr += _actually_read;
        } 

        if (std.system.endian != Endian.littleEndian) {
            switchEndianness(&block_size, int.sizeof);
        }

        // debug {
        //     stderr.writeln("[debug][BamReadRange] block size = ", block_size);
        // }

        _current_record = BamRead(_stream.readSlice(block_size));
        _current_record.associateWithReader(cast(IBamSamReader)_reader);
    }
}

/// Returns: lazy range of BamRead/BamReadBlock structs constructed from a given stream.
auto bamReadRange(alias IteratePolicy=withoutOffsets)(IChunkInputStream stream, BamReader reader) {
    return BamReadRange!IteratePolicy(stream, reader);
}
