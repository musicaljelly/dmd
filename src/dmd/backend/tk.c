/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/tk.c, backend/tk.c)
 */

#include        <stdio.h>
#include        <stdlib.h>
#include        <string.h>

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

#include        "mem.h"
#include        "filespec.c"

#if 0
#define malloc          ph_malloc
#define calloc(x,y)     ph_calloc((x) * (y))
#define realloc         ph_realloc
#define free            ph_free
#endif

#if !MEM_DEBUG
#define MEM_NOMEMCOUNT  1
#define MEM_NONEW       1
#endif
#include        "mem.c"
#include        "list.c"
#include        "vec.c"
