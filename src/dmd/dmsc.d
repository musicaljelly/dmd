/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/dmsc.d, _dmsc.d)
 * Documentation:  https://dlang.org/phobos/dmd_dmsc.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/dmsc.d
 */

module dmd.dmsc;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stddef;

extern (C++):

import dmd.globals;
import dmd.dclass;
import dmd.dmodule;
import dmd.mtype;

import dmd.root.filename;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.global;
import dmd.backend.ty;
import dmd.backend.type;

extern (C) void out_config_init(
        int model,      // 32: 32 bit code
                        // 64: 64 bit code
                        // Windows: bit 0 set to generate MS-COFF instead of OMF
        bool exe,       // true: exe file
                        // false: dll or shared library (generate PIC code)
        bool trace,     // add profiling code
        bool nofloat,   // do not pull in floating point code
        bool verbose,   // verbose compile
        bool optimize,  // optimize code
        int symdebug,   // add symbolic debug information
                        // 1: D
                        // 2: fake it with C symbolic debug info
        bool alwaysframe,       // always create standard function frame
        bool stackstomp,        // add stack stomping code
        ubyte avx,              // use AVX instruction set (0, 1, 2)
        PIC pic,                // kind of position independent code
        bool useModuleInfo,     // implement ModuleInfo
        bool useTypeInfo,       // implement TypeInfo
        bool useExceptions,     // implement exception handling
        string _version         // Compiler version
        );

void out_config_debug(
        bool debugb,
        bool debugc,
        bool debugf,
        bool debugr,
        bool debugw,
        bool debugx,
        bool debugy
    );

/**************************************
 * Initialize config variables.
 */

void backend_init()
{
    //printf("out_config_init()\n");
    Param *params = &global.params;

    bool exe;
    if (global.params.isWindows)
    {
        exe = false;
        if (params.dll)
        {
        }
        else if (params.run)
            exe = true;         // EXE file only optimizations
        else if (params.link && !global.params.deffile)
            exe = true;         // EXE file only optimizations
        else if (params.exefile.length)           // if writing out EXE file
        {
            if (params.exefile.length >= 4 && FileName.equals(params.exefile[$-3 .. $], "exe"))
                exe = true;
        }
    }
    else if (global.params.isLinux   ||
             global.params.isOSX     ||
             global.params.isFreeBSD ||
             global.params.isOpenBSD ||
             global.params.isDragonFlyBSD ||
             global.params.isSolaris)
    {
        exe = params.pic == PIC.fixed;
    }

    out_config_init(
        (params.is64bit ? 64 : 32) | (params.mscoff ? 1 : 0),
        exe,
        false, //params.trace,
        params.nofloat,
        params.verbose,
        params.optimize,
        params.symdebug,
        params.alwaysframe,
        params.stackstomp,
        params.cpu >= CPU.avx2 ? 2 : params.cpu >= CPU.avx ? 1 : 0,
        params.pic,
        params.useModuleInfo && Module.moduleinfo,
        params.useTypeInfo && Type.dtypeinfo,
        params.useExceptions && ClassDeclaration.throwable,
        global._version
    );

    debug
    {
        out_config_debug(
            params.debugb,
            params.debugc,
            params.debugf,
            params.debugr,
            false,
            params.debugx,
            params.debugy
        );
    }
}


/***********************************
 * Return aligned 'offset' if it is of size 'size'.
 */

targ_size_t _align(targ_size_t size, targ_size_t offset)
{
    switch (size)
    {
        case 1:
            break;
        case 2:
        case 4:
        case 8:
        case 16:
        case 32:
        case 64:
            offset = (offset + size - 1) & ~(size - 1);
            break;
        default:
            if (size >= 16)
                offset = (offset + 15) & ~15;
            else
                offset = (offset + _tysize[TYnptr] - 1) & ~(_tysize[TYnptr] - 1);
            break;
    }
    return offset;
}


/*******************************
 * Get size of ty
 */

targ_size_t size(tym_t ty)
{
    int sz = (tybasic(ty) == TYvoid) ? 1 : tysize(ty);
    debug
    {
        if (sz == -1)
            WRTYxx(ty);
    }
    assert(sz!= -1);
    return sz;
}

/****************************
 * Generate symbol of type ty at DATA:offset
 */

Symbol *symboldata(targ_size_t offset,tym_t ty)
{
    Symbol *s = symbol_generate(SClocstat, type_fake(ty));
    s.Sfl = FLdata;
    s.Soffset = offset;
    s.Stype.Tmangle = mTYman_sys; // writes symbol unmodified in Obj::mangle
    symbol_keep(s);               // keep around
    return s;
}

/**************************************
 */

void backend_term()
{
}
