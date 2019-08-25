/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 * Entry point for DMD.
 *
 * This modules defines the entry point (main) for DMD, as well as related
 * utilities needed for arguments parsing, path manipulation, etc...
 * This file is not shared with other compilers which use the DMD front-end.
 *
 * Copyright:   Copyright (c) 1999-2017 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/mars.d, _mars.d)
 * Documentation:  https://dlang.org/phobos/dmd_mars.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/mars.d
 */

module dmd.mars;

import core.stdc.ctype;
import core.stdc.limits;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import dmd.arraytypes;
import dmd.astcodegen;
import dmd.gluelayer;
import dmd.builtin;
import dmd.cond;
import dmd.console;
import dmd.dinifile;
import dmd.dinterpret;
import dmd.dmodule;
import dmd.doc;
import dmd.dscope;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.errors;
import dmd.expression;
import dmd.globals;
import dmd.hdrgen;
import dmd.id;
import dmd.identifier;
import dmd.inline;
import dmd.json;
import dmd.lib;
import dmd.link;
import dmd.mtype;
import dmd.objc;
import dmd.parse;
import dmd.root.array;
import dmd.root.file;
import dmd.root.filename;
import dmd.root.man;
import dmd.root.outbuffer;
import dmd.root.response;
import dmd.root.rmem;
import dmd.root.stringtable;
import dmd.semantic;
import dmd.target;
import dmd.tokens;
import dmd.utils;

/**
 * Print DMD's logo on stdout
 */
private void logo()
{
    printf("DMD%llu D Compiler %s\n%s %s\n", cast(ulong)size_t.sizeof * 8, global._version, global.copyright, global.written);
}


/**
 * Print DMD's usage message on stdout
 */
private  void usage()
{
    static if (TARGET_LINUX)
    {
        const(char)* fpic = "\n  -fPIC            generate position independent code";
    }
    else
    {
        const(char)* fpic = "";
    }
    static if (TARGET_WINDOS)
    {
        const(char)* m32mscoff = "\n  -m32mscoff       generate 32 bit code and write MS-COFF object files";
        const(char)* mscrtlib  = "\n  -mscrtlib=<name> MS C runtime library to reference from main/WinMain/DllMain";
    }
    else
    {
        const(char)* m32mscoff = "";
        const(char)* mscrtlib  = "";
    }
    logo();
    printf("
Documentation: http://dlang.org/
Config file: %s
Usage:
  dmd [<option>...] <file>...
  dmd [<option>...] -run <file> [<arg>...]

Where:
  <file>           D source file
  <arg>            Argument to pass when running the resulting program

<option>:
  @<cmdfile>       read arguments from cmdfile
  -allinst         generate code for all template instantiations
  -betterC         omit generating some runtime information and helper functions
  -boundscheck=[on|safeonly|off]   bounds checks on, in @safe only, or off
  -c               do not link
  -color           turn colored console output on
  -color=[on|off]  force colored console output on or off
  -conf=<filename> use config file at filename
  -cov             do code coverage analysis
  -cov=<nnn>       require at least nnn%% code coverage
  -D               generate documentation
  -Dd<directory>   write documentation file to directory
  -Df<filename>    write documentation file to filename
  -d               silently allow deprecated features
  -dw              show use of deprecated features as warnings (default)
  -de              show use of deprecated features as errors (halt compilation)
  -debug           compile in debug code
  -debug=<level>   compile in debug code <= level
  -debug=<ident>   compile in debug code identified by ident
  -debuglib=<name> set symbolic debug library to name
  -defaultlib=<name>
                   set default library to name
  -deps            print module dependencies (imports/file/version/debug/lib)
  -deps=<filename> write module dependencies to filename (only imports)" ~
  "%s" /* placeholder for fpic */ ~ "
  -dip25           implement http://wiki.dlang.org/DIP25 (experimental)
  -dip1000         implement http://wiki.dlang.org/DIP1000 (experimental)
  -dip1008         implement DIP1008 (experimental)
  -g               add symbolic debug info
  -gf              emit debug info for all referenced types
  -gs              always emit stack frame
  -gx              add stack stomp code
  -H               generate 'header' file
  -Hd=<directory>  write 'header' file to directory
  -Hf=<filename>   write 'header' file to filename
  --help           print help and exit
  -I=<directory>   look for imports also in directory
  -ignore          ignore unsupported pragmas
  -inline          do function inlining
  -J=<directory>   look for string imports also in directory
  -L=<linkerflag>  pass linkerflag to link
  -lib             generate library rather than object files
  -m32             generate 32 bit code" ~
  "%s" /* placeholder for m32mscoff */ ~ "
  -m64             generate 64 bit code
  -main            add default main() (e.g. for unittesting)
  -man             open web browser on manual page
  -map             generate linker .map file
  -mcpu=<id>       generate instructions for architecture identified by 'id'
  -mcpu=?          list all architecture options " ~
  "%s" /* placeholder for mscrtlib */ ~ "
  -mv=<package.module>=<filespec>  use <filespec> as source file for <package.module>
  -noboundscheck   no array bounds checking (deprecated, use -boundscheck=off)
  -O               optimize
  -o-              do not write object file
  -od=<directory>  write object & library files to directory
  -of=<filename>   name output file to filename
  -op              preserve source path for output files
  -profile         profile runtime performance of generated code
  -profile=gc      profile runtime allocations
  -release         compile release version
  -shared          generate shared library (DLL)
  -transition=<id> help with language change identified by 'id'
  -transition=?    list all language changes
  -unittest        compile in unit tests
  -v               verbose
  -vcolumns        print character (column) numbers in diagnostics
  -verrors=<num>   limit the number of error messages (0 means unlimited)
  -verrors=spec    show errors from speculative compiles such as __traits(compiles,...)
  -vgc             list all gc allocations including hidden ones
  -vtls            list all variables going into thread local storage
  --version        print compiler version and exit
  -version=<level> compile in version code >= level
  -version=<ident> compile in version code identified by ident
  -w               warnings as errors (compilation will halt)
  -wi              warnings as messages (compilation will continue)
  -X               generate JSON file
  -Xf=<filename>   write JSON file to filename
", FileName.canonicalName(global.inifilename), fpic, m32mscoff, mscrtlib);
}

/// DMD-generated module `__entrypoint` where the C main resides
extern (C++) __gshared Module entrypoint = null;
/// Module in which the D main is
extern (C++) __gshared Module rootHasMain = null;


/**
 * Generate C main() in response to seeing D main().
 *
 * This function will generate a module called `__entrypoint`,
 * and set the globals `entrypoint` and `rootHasMain`.
 *
 * This used to be in druntime, but contained a reference to _Dmain
 * which didn't work when druntime was made into a dll and was linked
 * to a program, such as a C++ program, that didn't have a _Dmain.
 *
 * Params:
 *   sc = Scope which triggered the generation of the C main,
 *        used to get the module where the D main is.
 */
extern (C++) void genCmain(Scope* sc)
{
    if (entrypoint)
        return;
    /* The D code to be generated is provided as D source code in the form of a string.
     * Note that Solaris, for unknown reasons, requires both a main() and an _main()
     */
    immutable cmaincode =
    q{
        extern(C)
        {
            int _d_run_main(int argc, char **argv, void* mainFunc);
            int _Dmain(char[][] args);
            int main(int argc, char **argv)
            {
                return _d_run_main(argc, argv, &_Dmain);
            }
            version (Solaris) int _main(int argc, char** argv) { return main(argc, argv); }
        }
    };
    Identifier id = Id.entrypoint;
    auto m = new Module("__entrypoint.d", id, 0, 0);
    scope p = new Parser!ASTCodegen(m, cmaincode, false);
    p.scanloc = Loc();
    p.nextToken();
    m.members = p.parseModule();
    assert(p.token.value == TOKeof);
    assert(!p.errors); // shouldn't have failed to parse it
    bool v = global.params.verbose;
    global.params.verbose = false;
    m.importedFrom = m;
    m.importAll(null);
    m.dsymbolSemantic(null);
    m.semantic2(null);
    m.semantic3(null);
    global.params.verbose = v;
    entrypoint = m;
    rootHasMain = sc._module;
}


/**
 * DMD's real entry point
 *
 * Parses command line arguments and config file, open and read all
 * provided source file and do semantic analysis on them.
 *
 * Params:
 *   argc = Number of arguments passed via command line
 *   argv = Array of string arguments passed via command line
 *
 * Returns:
 *   Application return code
 */
private int tryMain(size_t argc, const(char)** argv)
{
    Strings files;
    Strings libmodules;
    global._init();
    debug
    {
        printf("DMD %s DEBUG\n", global._version);
        fflush(stdout); // avoid interleaving with stderr output when redirecting
    }
    // Check for malformed input
    if (argc < 1 || !argv)
    {
    Largs:
        error(Loc(), "missing or null command line arguments");
        fatal();
    }
    // Convert argc/argv into arguments[] for easier handling
    Strings arguments;
    arguments.setDim(argc);
    for (size_t i = 0; i < argc; i++)
    {
        if (!argv[i])
            goto Largs;
        arguments[i] = argv[i];
    }
    if (response_expand(&arguments)) // expand response files
        error(Loc(), "can't open response file");
    //for (size_t i = 0; i < arguments.dim; ++i) printf("arguments[%d] = '%s'\n", i, arguments[i]);
    files.reserve(arguments.dim - 1);
    // Set default values
    global.params.argv0 = arguments[0];

    // Temporary: Use 32 bits as the default on Windows, for config parsing
    static if (TARGET_WINDOS)
        global.params.is64bit = false;

    global.inifilename = parse_conf_arg(&arguments);
    if (global.inifilename)
    {
        // can be empty as in -conf=
        if (strlen(global.inifilename) && !FileName.exists(global.inifilename))
            error(Loc(), "Config file '%s' does not exist.", global.inifilename);
    }
    else
    {
        version (Windows)
        {
            global.inifilename = findConfFile(global.params.argv0, "sc.ini");
        }
        else version (Posix)
        {
            global.inifilename = findConfFile(global.params.argv0, "dmd.conf");
        }
        else
        {
            static assert(0, "fix this");
        }
    }
    // Read the configurarion file
    auto inifile = File(global.inifilename);
    inifile.read();
    /* Need path of configuration file, for use in expanding @P macro
     */
    const(char)* inifilepath = FileName.path(global.inifilename);
    Strings sections;
    StringTable environment;
    environment._init(7);
    /* Read the [Environment] section, so we can later
     * pick up any DFLAGS settings.
     */
    sections.push("Environment");
    parseConfFile(&environment, global.inifilename, inifilepath, inifile.len, inifile.buffer, &sections);
    Strings dflags;
    getenv_setargv(readFromEnv(&environment, "DFLAGS"), &dflags);
    environment.reset(7); // erase cached environment updates
    const(char)* arch = global.params.is64bit ? "64" : "32"; // use default
    arch = parse_arch_arg(&arguments, arch);
    arch = parse_arch_arg(&dflags, arch);
    bool is64bit = arch[0] == '6';

    version(Windows) // delete LIB entry in [Environment] (necessary for optlink) to allow inheriting environment for MS-COFF
        if (is64bit || strcmp(arch, "32mscoff") == 0)
            environment.update("LIB", 3).ptrvalue = null;

    char[80] envsection;
    sprintf(envsection.ptr, "Environment%s", arch);
    sections.push(envsection.ptr);
    parseConfFile(&environment, global.inifilename, inifilepath, inifile.len, inifile.buffer, &sections);
    getenv_setargv(readFromEnv(&environment, "DFLAGS"), &arguments);
    updateRealEnvironment(&environment);
    environment.reset(1); // don't need environment cache any more

    if (parseCommandLine(arguments, argc, global.params, files))
    {
        Loc loc;
        errorSupplemental(loc, "run 'dmd -man' to open browser on manual");
        return EXIT_FAILURE;
    }

    if (global.params.usage)
    {
        usage();
        return EXIT_SUCCESS;
    }

    if (global.params.logo)
    {
        logo();
        return EXIT_SUCCESS;
    }

    if (global.params.mcpuUsage)
    {
        printf("
CPU architectures supported by -mcpu=id:
  =?             list information on all architecture choices
  =baseline      use default architecture as determined by target
  =avx           use AVX 1 instructions
  =avx2          use AVX 2 instructions
  =native        use CPU architecture that this compiler is running on
");
        return EXIT_SUCCESS;
    }

    if (global.params.transitionUsage)
    {
         printf("
Language changes listed by -transition=id:
  =all           list information on all language changes
  =checkimports  give deprecation messages about 10378 anomalies
  =complex,14488 list all usages of complex or imaginary types
  =field,3449    list all non-mutable fields which occupy an object instance
  =import,10378  revert to single phase name lookup
  =intpromote,16997 fix integral promotions for unary + - ~ operators
  =tls           list all variables going into thread local storage
");
        return EXIT_SUCCESS;
    }

    if (global.params.manual)
    {
        version (Windows)
        {
            browse("http://dlang.org/dmd-windows.html");
        }
        version (linux)
        {
            browse("http://dlang.org/dmd-linux.html");
        }
        version (OSX)
        {
            browse("http://dlang.org/dmd-osx.html");
        }
        version (FreeBSD)
        {
            browse("http://dlang.org/dmd-freebsd.html");
        }
        version (OpenBSD)
        {
            browse("http://dlang.org/dmd-openbsd.html");
        }
        return EXIT_SUCCESS;
    }

    if (global.params.color)
        global.console = Console.create(core.stdc.stdio.stderr);

    global.params.cpu = setTargetCPU(global.params.cpu);
    if (global.params.is64bit != is64bit)
        error(Loc(), "the architecture must not be changed in the %s section of %s", envsection.ptr, global.inifilename);
    if (global.params.enforcePropertySyntax)
    {
        /*NOTE: -property used to disallow calling non-properties
         without parentheses. This behaviour has fallen from grace.
         Phobos dropped support for it while dmd still recognized it, so
         that the switch has effectively not been supported. Time to
         remove it from dmd.
         Step 1 (2.069): Deprecate -property and ignore it. */
        Loc loc;
        deprecation(loc, "The -property switch is deprecated and has no " ~
            "effect anymore.");
        /* Step 2: Remove -property. Throw an error when it's set.
         Do this by removing global.params.enforcePropertySyntax and the code
         above that sets it. Let it be handled as an unrecognized switch.
         Step 3: Possibly reintroduce -property with different semantics.
         Any new semantics need to be decided on first. */
    }
    // Target uses 64bit pointers.
    global.params.isLP64 = global.params.is64bit;
    if (global.errors)
    {
        fatal();
    }
    if (files.dim == 0)
    {
        usage();
        return EXIT_FAILURE;
    }
    static if (TARGET_OSX)
    {
        global.params.pic = 1;
    }
    static if (TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
    {
        if (global.params.lib && global.params.dll)
            error(Loc(), "cannot mix -lib and -shared");
    }
    static if (TARGET_WINDOS)
    {
        if (!global.params.mscrtlib)
            global.params.mscrtlib = "libcmt";
    }
    if (global.params.release)
    {
        global.params.useInvariants = false;
        global.params.useIn = false;
        global.params.useOut = false;

        if (global.params.useArrayBounds == CHECKENABLE._default)
            global.params.useArrayBounds = CHECKENABLE.safeonly;

        if (global.params.useAssert == CHECKENABLE._default)
            global.params.useAssert = CHECKENABLE.off;

        if (global.params.useSwitchError == CHECKENABLE._default)
            global.params.useSwitchError = CHECKENABLE.off;
    }
    if (global.params.betterC)
    {
        global.params.checkAction = CHECKACTION.C;
        global.params.useModuleInfo = false;
        global.params.useTypeInfo = false;
        global.params.useExceptions = false;
    }
    if (global.params.useUnitTests)
        global.params.useAssert = CHECKENABLE.on;

    if (global.params.useArrayBounds == CHECKENABLE._default)
        global.params.useArrayBounds = CHECKENABLE.on;

    if (global.params.useAssert == CHECKENABLE._default)
        global.params.useAssert = CHECKENABLE.on;

    if (global.params.useSwitchError == CHECKENABLE._default)
        global.params.useSwitchError = CHECKENABLE.on;

    if (!global.params.obj || global.params.lib)
        global.params.link = false;
    if (global.params.link)
    {
        global.params.exefile = global.params.objname;
        global.params.oneobj = true;
        if (global.params.objname)
        {
            /* Use this to name the one object file with the same
             * name as the exe file.
             */
            global.params.objname = cast(char*)FileName.forceExt(global.params.objname, global.obj_ext);
            /* If output directory is given, use that path rather than
             * the exe file path.
             */
            if (global.params.objdir)
            {
                const(char)* name = FileName.name(global.params.objname);
                global.params.objname = cast(char*)FileName.combine(global.params.objdir, name);
            }
        }
    }
    else if (global.params.run)
    {
        error(Loc(), "flags conflict with -run");
        fatal();
    }
    else if (global.params.lib)
    {
        global.params.libname = global.params.objname;
        global.params.objname = null;
        // Haven't investigated handling these options with multiobj
        if (!global.params.cov && !global.params.trace)
            global.params.multiobj = true;
    }
    else
    {
        if (global.params.objname && files.dim > 1)
        {
            global.params.oneobj = true;
            //error("multiple source files, but only one .obj name");
            //fatal();
        }
    }

    // Add in command line versions
    if (global.params.versionids)
        foreach (charz; *global.params.versionids)
            VersionCondition.addGlobalIdent(charz[0 .. strlen(charz)]);
    if (global.params.debugids)
        foreach (charz; *global.params.debugids)
            DebugCondition.addGlobalIdent(charz[0 .. strlen(charz)]);

    // Predefined version identifiers
    addDefaultVersionIdentifiers();

    setDefaultLibrary();

    // Initialization
    Type._init();
    Id.initialize();
    Module._init();
    Target._init();
    Expression._init();
    Objc._init();
    builtin_init();

    if (global.params.verbose)
    {
        fprintf(global.stdmsg, "binary    %s\n", global.params.argv0);
        fprintf(global.stdmsg, "version   %s\n", global._version);
        fprintf(global.stdmsg, "config    %s\n", global.inifilename ? global.inifilename : "(none)");
    }
    //printf("%d source files\n",files.dim);

    // Build import search path

    static Strings* buildPath(Strings* imppath)
    {
        Strings* result = null;
        if (imppath)
        {
            foreach (const path; *imppath)
            {
                Strings* a = FileName.splitPath(path);
                if (a)
                {
                    if (!result)
                        result = new Strings();
                    result.append(a);
                }
            }
        }
        return result;
    }

    global.path = buildPath(global.params.imppath);
    global.filePath = buildPath(global.params.fileImppath);

    if (global.params.addMain)
    {
        files.push(cast(char*)global.main_d); // a dummy name, we never actually look up this file
    }
    // Create Modules
    Modules modules;
    modules.reserve(files.dim);
    bool firstmodule = true;
    for (size_t i = 0; i < files.dim; i++)
    {
        const(char)* name;
        version (Windows)
        {
            files[i] = toWinPath(files[i]);
        }
        const(char)* p = files[i];
        p = FileName.name(p); // strip path
        const(char)* ext = FileName.ext(p);
        char* newname;
        if (ext)
        {
            /* Deduce what to do with a file based on its extension
             */
            if (FileName.equals(ext, global.obj_ext))
            {
                global.params.objfiles.push(files[i]);
                libmodules.push(files[i]);
                continue;
            }
            if (FileName.equals(ext, global.lib_ext))
            {
                global.params.libfiles.push(files[i]);
                libmodules.push(files[i]);
                continue;
            }
            static if (TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
            {
                if (FileName.equals(ext, global.dll_ext))
                {
                    global.params.dllfiles.push(files[i]);
                    libmodules.push(files[i]);
                    continue;
                }
            }
            if (strcmp(ext, global.ddoc_ext) == 0)
            {
                global.params.ddocfiles.push(files[i]);
                continue;
            }
            if (FileName.equals(ext, global.json_ext))
            {
                global.params.doJsonGeneration = true;
                global.params.jsonfilename = files[i];
                continue;
            }
            if (FileName.equals(ext, global.map_ext))
            {
                global.params.mapfile = files[i];
                continue;
            }
            static if (TARGET_WINDOS)
            {
                if (FileName.equals(ext, "res"))
                {
                    global.params.resfile = files[i];
                    continue;
                }
                if (FileName.equals(ext, "def"))
                {
                    global.params.deffile = files[i];
                    continue;
                }
                if (FileName.equals(ext, "exe"))
                {
                    assert(0); // should have already been handled
                }
            }
            /* Examine extension to see if it is a valid
             * D source file extension
             */
            if (FileName.equals(ext, global.mars_ext) || FileName.equals(ext, global.hdr_ext) || FileName.equals(ext, "dd"))
            {
                ext--; // skip onto '.'
                assert(*ext == '.');
                newname = cast(char*)mem.xmalloc((ext - p) + 1);
                memcpy(newname, p, ext - p);
                newname[ext - p] = 0; // strip extension
                name = newname;
                if (name[0] == 0 || strcmp(name, "..") == 0 || strcmp(name, ".") == 0)
                {
                Linvalid:
                    error(Loc(), "invalid file name '%s'", files[i]);
                    fatal();
                }
            }
            else
            {
                error(Loc(), "unrecognized file extension %s", ext);
                fatal();
            }
        }
        else
        {
            name = p;
            if (!*name)
                goto Linvalid;
        }
        /* At this point, name is the D source file name stripped of
         * its path and extension.
         */
        auto id = Identifier.idPool(name, strlen(name));
        auto m = new Module(files[i], id, global.params.doDocComments, global.params.doHdrGeneration);
        modules.push(m);
        if (firstmodule)
        {
            global.params.objfiles.push(m.objfile.name.str);
            firstmodule = false;
        }
    }
    // Read files
    /* Start by "reading" the dummy main.d file
     */
    if (global.params.addMain)
    {
        bool added = false;
        foreach (m; modules)
        {
            if (strcmp(m.srcfile.name.str, global.main_d) == 0)
            {
                string buf = "int main(){return 0;}";
                m.srcfile.setbuffer(cast(void*)buf.ptr, buf.length);
                m.srcfile._ref = 1;
                added = true;
                break;
            }
        }
        assert(added);
    }
    enum ASYNCREAD = false;
    static if (ASYNCREAD)
    {
        // Multi threaded
        AsyncRead* aw = AsyncRead.create(modules.dim);
        foreach (m; modules)
        {
            aw.addFile(m.srcfile);
        }
        aw.start();
    }
    else
    {
        // Single threaded
        foreach (m; modules)
        {
            m.read(Loc());
        }
    }
    // Parse files
    bool anydocfiles = false;
    size_t filecount = modules.dim;
    for (size_t filei = 0, modi = 0; filei < filecount; filei++, modi++)
    {
        Module m = modules[modi];
        if (global.params.verbose)
            fprintf(global.stdmsg, "parse     %s\n", m.toChars());
        if (!Module.rootModule)
            Module.rootModule = m;
        m.importedFrom = m; // m.isRoot() == true
        if (!global.params.oneobj || modi == 0 || m.isDocFile)
            m.deleteObjFile();
        static if (ASYNCREAD)
        {
            if (aw.read(filei))
            {
                error(Loc(), "cannot read file %s", m.srcfile.name.toChars());
                fatal();
            }
        }
        m.parse();
        if (m.isDocFile)
        {
            anydocfiles = true;
            gendocfile(m);
            // Remove m from list of modules
            modules.remove(modi);
            modi--;
            // Remove m's object file from list of object files
            for (size_t j = 0; j < global.params.objfiles.dim; j++)
            {
                if (m.objfile.name.str == global.params.objfiles[j])
                {
                    global.params.objfiles.remove(j);
                    break;
                }
            }
            if (global.params.objfiles.dim == 0)
                global.params.link = false;
        }
    }
    static if (ASYNCREAD)
    {
        AsyncRead.dispose(aw);
    }
    if (anydocfiles && modules.dim && (global.params.oneobj || global.params.objname))
    {
        error(Loc(), "conflicting Ddoc and obj generation options");
        fatal();
    }
    if (global.errors)
        fatal();

    if (global.params.doHdrGeneration)
    {
        /* Generate 'header' import files.
         * Since 'header' import files must be independent of command
         * line switches and what else is imported, they are generated
         * before any semantic analysis.
         */
        foreach (m; modules)
        {
            if (global.params.verbose)
                fprintf(global.stdmsg, "import    %s\n", m.toChars());
            genhdrfile(m);
        }
    }
    if (global.errors)
        fatal();

    // load all unconditional imports for better symbol resolving
    foreach (m; modules)
    {
        if (global.params.verbose)
            fprintf(global.stdmsg, "importall %s\n", m.toChars());
        m.importAll(null);
    }
    if (global.errors)
        fatal();

    backend_init();

    // Do semantic analysis
    foreach (m; modules)
    {
        if (global.params.verbose)
            fprintf(global.stdmsg, "semantic  %s\n", m.toChars());
        m.dsymbolSemantic(null);
    }
    //if (global.errors)
    //    fatal();
    Module.dprogress = 1;
    Module.runDeferredSemantic();
    if (Module.deferred.dim)
    {
        for (size_t i = 0; i < Module.deferred.dim; i++)
        {
            Dsymbol sd = Module.deferred[i];
            sd.error("unable to resolve forward reference in definition");
        }
        //fatal();
    }

    // Do pass 2 semantic analysis
    foreach (m; modules)
    {
        if (global.params.verbose)
            fprintf(global.stdmsg, "semantic2 %s\n", m.toChars());
        m.semantic2(null);
    }
    Module.runDeferredSemantic2();
    if (global.errors)
        fatal();

    // Do pass 3 semantic analysis
    foreach (m; modules)
    {
        if (global.params.verbose)
            fprintf(global.stdmsg, "semantic3 %s\n", m.toChars());
        m.semantic3(null);
    }
    Module.runDeferredSemantic3();
    if (global.errors)
        fatal();

    // Scan for functions to inline
    if (global.params.useInline)
    {
        foreach (m; modules)
        {
            if (global.params.verbose)
                fprintf(global.stdmsg, "inline scan %s\n", m.toChars());
            inlineScanModule(m);
        }
    }
    // Do not attempt to generate output files if errors or warnings occurred
    if (global.errors || global.warnings)
        fatal();

    // inlineScan incrementally run semantic3 of each expanded functions.
    // So deps file generation should be moved after the inlinig stage.
    if (global.params.moduleDeps)
    {
        foreach (i; 1 .. modules[0].aimports.dim)
            semantic3OnDependencies(modules[0].aimports[i]);

        OutBuffer* ob = global.params.moduleDeps;
        if (global.params.moduleDepsFile)
        {
            auto deps = File(global.params.moduleDepsFile);
            deps.setbuffer(cast(void*)ob.data, ob.offset);
            writeFile(Loc(), &deps);
        }
        else
            printf("%.*s", cast(int)ob.offset, ob.data);
    }

    printCtfePerformanceStats();

    Library library = null;
    if (global.params.lib)
    {
        library = Library.factory();
        library.setFilename(global.params.objdir, global.params.libname);
        // Add input object and input library files to output library
        for (size_t i = 0; i < libmodules.dim; i++)
        {
            const(char)* p = libmodules[i];
            library.addObject(p, null);
        }
    }
    // Generate output files
    if (global.params.doJsonGeneration)
    {
        OutBuffer buf;
        json_generate(&buf, &modules);
        // Write buf to file
        const(char)* name = global.params.jsonfilename;
        if (name && name[0] == '-' && name[1] == 0)
        {
            // Write to stdout; assume it succeeds
            size_t n = fwrite(buf.data, 1, buf.offset, stdout);
            assert(n == buf.offset); // keep gcc happy about return values
        }
        else
        {
            /* The filename generation code here should be harmonized with Module::setOutfile()
             */
            const(char)* jsonfilename;
            if (name && *name)
            {
                jsonfilename = FileName.defaultExt(name, global.json_ext);
            }
            else
            {
                // Generate json file name from first obj name
                const(char)* n = global.params.objfiles[0];
                n = FileName.name(n);
                //if (!FileName::absolute(name))
                //    name = FileName::combine(dir, name);
                jsonfilename = FileName.forceExt(n, global.json_ext);
            }
            ensurePathToNameExists(Loc(), jsonfilename);
            auto jsonfile = new File(jsonfilename);
            jsonfile.setbuffer(buf.data, buf.offset);
            jsonfile._ref = 1;
            writeFile(Loc(), jsonfile);
        }
    }
    if (!global.errors && global.params.doDocComments)
    {
        foreach (m; modules)
        {
            gendocfile(m);
        }
    }
    if (global.params.vcg_ast)
    {
        import dmd.hdrgen;
        foreach (mod; modules)
        {
            auto buf = OutBuffer();
            buf.doindent = 1;
            scope HdrGenState hgs;
            hgs.fullDump = 1;
            scope PrettyPrintVisitor ppv = new PrettyPrintVisitor(&buf, &hgs);
            mod.accept(ppv);

            // write the output to $(filename).cg
            auto modFilename = mod.srcfile.toChars();
            auto modFilenameLength = strlen(modFilename);
            auto cgFilename = cast(char*)allocmemory(modFilenameLength + 4);
            memcpy(cgFilename, modFilename, modFilenameLength);
            cgFilename[modFilenameLength .. modFilenameLength + 4] = ".cg\0";
            auto cgFile = File(cgFilename);
            cgFile.setbuffer(buf.data, buf.offset);
            cgFile._ref = 1;
            cgFile.write();
        }
    }
    if (!global.params.obj)
    {
    }
    else if (global.params.oneobj)
    {
        if (modules.dim)
            obj_start(cast(char*)modules[0].srcfile.toChars());
        foreach (m; modules)
        {
            if (global.params.verbose)
                fprintf(global.stdmsg, "code      %s\n", m.toChars());
            genObjFile(m, false);
            if (entrypoint && m == rootHasMain)
                genObjFile(entrypoint, false);
        }
        if (!global.errors && modules.dim)
        {
            obj_end(library, modules[0].objfile);
        }
    }
    else
    {
        foreach (m; modules)
        {
            if (global.params.verbose)
                fprintf(global.stdmsg, "code      %s\n", m.toChars());
            obj_start(cast(char*)m.srcfile.toChars());
            genObjFile(m, global.params.multiobj);
            if (entrypoint && m == rootHasMain)
                genObjFile(entrypoint, global.params.multiobj);
            obj_end(library, m.objfile);
            obj_write_deferred(library);
            if (global.errors && !global.params.lib)
                m.deleteObjFile();
        }
    }
    if (global.params.lib && !global.errors)
        library.write();
    backend_term();
    if (global.errors)
        fatal();
    int status = EXIT_SUCCESS;
    if (!global.params.objfiles.dim)
    {
        if (global.params.link)
            error(Loc(), "no object files to link");
    }
    else
    {
        if (global.params.link)
            status = runLINK();
        if (global.params.run)
        {
            if (!status)
            {
                status = runProgram();
                /* Delete .obj files and .exe file
                 */
                foreach (m; modules)
                {
                    m.deleteObjFile();
                    if (global.params.oneobj)
                        break;
                }
                remove(global.params.exefile);
            }
        }
    }
    return status;
}


/**
 * Entry point which forwards to `tryMain`.
 *
 * Returns:
 *   Return code of the application
 */
version(NoMain) {} else
int main()
{
    import core.memory;
    import core.runtime;

    version (GC)
    {
    }
    else
    {
        GC.disable();
    }
    version(D_Coverage)
    {
        // for now we need to manually set the source path
        string dirName(string path, char separator)
        {
            for (size_t i = path.length - 1; i > 0; i--)
            {
                if (path[i] == separator)
                    return path[0..i];
            }
            return path;
        }
        version (Windows)
            enum sourcePath = dirName(dirName(__FILE_FULL_PATH__, `\`), `\`);
        else
            enum sourcePath = dirName(dirName(__FILE_FULL_PATH__, '/'), '/');

        dmd_coverSourcePath(sourcePath);
        dmd_coverDestPath(sourcePath);
        dmd_coverSetMerge(true);
    }

    auto args = Runtime.cArgs();
    return tryMain(args.argc, cast(const(char)**)args.argv);
}


/**
 * Parses an environment variable containing command-line flags
 * and append them to `args`.
 *
 * This function is used to read the content of DFLAGS.
 * Flags are separated based on spaces and tabs.
 *
 * Params:
 *   envvalue = The content of an environment variable
 *   args     = Array to append the flags to, if any.
 */
private void getenv_setargv(const(char)* envvalue, Strings* args)
{
    if (!envvalue)
        return;
    char* p;
    int instring;
    int slash;
    char c;
    char* env = mem.xstrdup(envvalue); // create our own writable copy
    //printf("env = '%s'\n", env);
    while (1)
    {
        switch (*env)
        {
        case ' ':
        case '\t':
            env++;
            break;
        case 0:
            return;
        default:
            args.push(env); // append
            p = env;
            slash = 0;
            instring = 0;
            c = 0;
            while (1)
            {
                c = *env++;
                switch (c)
                {
                case '"':
                    p -= (slash >> 1);
                    if (slash & 1)
                    {
                        p--;
                        goto Laddc;
                    }
                    instring ^= 1;
                    slash = 0;
                    continue;
                case ' ':
                case '\t':
                    if (instring)
                        goto Laddc;
                    *p = 0;
                    //if (wildcard)
                    //    wildcardexpand();     // not implemented
                    break;
                case '\\':
                    slash++;
                    *p++ = c;
                    continue;
                case 0:
                    *p = 0;
                    //if (wildcard)
                    //    wildcardexpand();     // not implemented
                    return;
                default:
                Laddc:
                    slash = 0;
                    *p++ = c;
                    continue;
                }
                break;
            }
        }
    }
}

/**
 * Parse command line arguments for -m32 or -m64
 * to detect the desired architecture.
 *
 * Params:
 *   args = Command line arguments
 *   arch = Default value to use for architecture.
 *          Should be "32" or "64"
 *
 * Returns:
 *   "32", "64" or "32mscoff" if the "-m32", "-m64", "-m32mscoff" flags were passed,
 *   respectively. If they weren't, return `arch`.
 */
private const(char)* parse_arch_arg(Strings* args, const(char)* arch)
{
    for (size_t i = 0; i < args.dim; ++i)
    {
        const(char)* p = (*args)[i];
        if (p[0] == '-')
        {
            if (strcmp(p + 1, "m32") == 0 || strcmp(p + 1, "m32mscoff") == 0 || strcmp(p + 1, "m64") == 0)
                arch = p + 2;
            else if (strcmp(p + 1, "run") == 0)
                break;
        }
    }
    return arch;
}


/**
 * Parse command line arguments for -conf=path.
 *
 * Params:
 *   args = Command line arguments
 *
 * Returns:
 *   Path to the config file to use
 */
private const(char)* parse_conf_arg(Strings* args)
{
    const(char)* conf = null;
    for (size_t i = 0; i < args.dim; ++i)
    {
        const(char)* p = (*args)[i];
        if (p[0] == '-')
        {
            if (strncmp(p + 1, "conf=", 5) == 0)
                conf = p + 6;
            else if (strcmp(p + 1, "run") == 0)
                break;
        }
    }
    return conf;
}


/**
 * Set the default and debug libraries to link against, if not already set
 *
 * Must be called after argument parsing is done, as it won't
 * override any value.
 * Note that if `-defaultlib=` or `-debuglib=` was used,
 * we don't override that either.
 */
private void setDefaultLibrary()
{
    if (global.params.defaultlibname is null)
    {
        static if (TARGET_WINDOS)
        {
            if (global.params.is64bit)
                global.params.defaultlibname = "phobos64";
            else if (global.params.mscoff)
                global.params.defaultlibname = "phobos32mscoff";
            else
                global.params.defaultlibname = "phobos";
        }
        else static if (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
        {
            global.params.defaultlibname = "libphobos2.a";
        }
        else static if (TARGET_OSX)
        {
            global.params.defaultlibname = "phobos2";
        }
        else
        {
            static assert(0, "fix this");
        }
    }
    if (global.params.debuglibname is null)
        global.params.debuglibname = global.params.defaultlibname;
}


/**
 * Add default `version` identifier for dmd, and set the
 * target platform in `global`.
 * https://dlang.org/spec/version.html#predefined-versions
 *
 * Needs to be run after all arguments parsing (command line, DFLAGS environment
 * variable and config file) in order to add final flags (such as `X86_64` or
 * the `CRuntime` used).
 */
private void addDefaultVersionIdentifiers()
{
    VersionCondition.addPredefinedGlobalIdent("DigitalMars");
    static if (TARGET_WINDOS)
    {
        VersionCondition.addPredefinedGlobalIdent("Windows");
        global.params.isWindows = true;
    }
    else static if (TARGET_LINUX)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("linux");
        VersionCondition.addPredefinedGlobalIdent("ELFv1");
        global.params.isLinux = true;
    }
    else static if (TARGET_OSX)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("OSX");
        global.params.isOSX = true;
        // For legacy compatibility
        VersionCondition.addPredefinedGlobalIdent("darwin");
    }
    else static if (TARGET_FREEBSD)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("FreeBSD");
        VersionCondition.addPredefinedGlobalIdent("ELFv1");
        global.params.isFreeBSD = true;
    }
    else static if (TARGET_OPENBSD)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("OpenBSD");
        VersionCondition.addPredefinedGlobalIdent("ELFv1");
        global.params.isOpenBSD = true;
    }
    else static if (TARGET_SOLARIS)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("Solaris");
        VersionCondition.addPredefinedGlobalIdent("ELFv1");
        global.params.isSolaris = true;
    }
    else
    {
        static assert(0, "fix this");
    }
    VersionCondition.addPredefinedGlobalIdent("LittleEndian");
    VersionCondition.addPredefinedGlobalIdent("D_Version2");
    VersionCondition.addPredefinedGlobalIdent("all");

    if (global.params.cpu >= CPU.sse2)
    {
        VersionCondition.addPredefinedGlobalIdent("D_SIMD");
        if (global.params.cpu >= CPU.avx)
            VersionCondition.addPredefinedGlobalIdent("D_AVX");
        if (global.params.cpu >= CPU.avx2)
            VersionCondition.addPredefinedGlobalIdent("D_AVX2");
    }

    if (global.params.is64bit)
    {
        VersionCondition.addPredefinedGlobalIdent("D_InlineAsm_X86_64");
        VersionCondition.addPredefinedGlobalIdent("X86_64");
        static if (TARGET_WINDOS)
        {
            VersionCondition.addPredefinedGlobalIdent("Win64");
        }
    }
    else
    {
        VersionCondition.addPredefinedGlobalIdent("D_InlineAsm"); //legacy
        VersionCondition.addPredefinedGlobalIdent("D_InlineAsm_X86");
        VersionCondition.addPredefinedGlobalIdent("X86");
        static if (TARGET_WINDOS)
        {
            VersionCondition.addPredefinedGlobalIdent("Win32");
        }
    }
    static if (TARGET_WINDOS)
    {
        if (global.params.mscoff)
            VersionCondition.addPredefinedGlobalIdent("CRuntime_Microsoft");
        else
            VersionCondition.addPredefinedGlobalIdent("CRuntime_DigitalMars");
    }
    else static if (TARGET_LINUX)
    {
        VersionCondition.addPredefinedGlobalIdent("CRuntime_Glibc");
    }

    if (global.params.isLP64)
        VersionCondition.addPredefinedGlobalIdent("D_LP64");
    if (global.params.doDocComments)
        VersionCondition.addPredefinedGlobalIdent("D_Ddoc");
    if (global.params.cov)
        VersionCondition.addPredefinedGlobalIdent("D_Coverage");
    if (global.params.pic)
        VersionCondition.addPredefinedGlobalIdent("D_PIC");
    if (global.params.useUnitTests)
        VersionCondition.addPredefinedGlobalIdent("unittest");
    if (global.params.useAssert == CHECKENABLE.on)
        VersionCondition.addPredefinedGlobalIdent("assert");
    if (global.params.useArrayBounds == CHECKENABLE.off)
        VersionCondition.addPredefinedGlobalIdent("D_NoBoundsChecks");
    if (global.params.betterC)
        VersionCondition.addPredefinedGlobalIdent("D_BetterC");

    VersionCondition.addPredefinedGlobalIdent("D_HardFloat");

    printPredefinedVersions();
}

private void printPredefinedVersions()
{
    if (global.params.verbose && global.versionids)
    {
        fprintf(global.stdmsg, "predefs  ");
        foreach (const str; *global.versionids)
            fprintf(global.stdmsg, " %s", str.toChars);

        fprintf(global.stdmsg, "\n");
    }
}


/****************************************
 * Determine the instruction set to be used.
 * Params:
 *      cpu = value set by command line switch
 * Returns:
 *      value to generate code for
 */

private CPU setTargetCPU(CPU cpu)
{
    // Determine base line for target
    CPU baseline = CPU.x87;
    if (global.params.is64bit)
        baseline = CPU.sse2;
    else
    {
        static if (TARGET_OSX)
        {
            baseline = CPU.sse2;
        }
    }

    if (baseline < CPU.sse2)
        return baseline;        // can't support other instruction sets

    switch (cpu)
    {
        case CPU.baseline:
            cpu = baseline;
            break;

        case CPU.native:
        {
            import core.cpuid;
            cpu = baseline;
            if (core.cpuid.avx2)
                cpu = CPU.avx2;
            else if (core.cpuid.avx)
                cpu = CPU.avx;
            break;
        }

        default:
            break;
    }
    return cpu;
}


/****************************************************
 * Parse command line arguments.
 *
 * Prints message(s) if there are errors.
 *
 * Params:
 *      arguments = command line arguments
 *      argc = argument count
 *      params = set to result of parsing `arguments`
 *      files = set to files pulled from `arguments`
 * Returns:
 *      true if errors in command line
 */

private bool parseCommandLine(const ref Strings arguments, const size_t argc, ref Param params, ref Strings files)
{
    bool errors;

    void error(const(char)* format, const(char*) arg = null)
    {
        dmd.errors.error(Loc(), format, arg);
        errors = true;
    }

    /************************************
     * Convert string to integer.
     * Params:
     *  p = pointer to start of string digits, ending with 0
     *  max = max allowable value (inclusive)
     * Returns:
     *  uint.max on error, otherwise converted integer
     */
    static pure uint parseDigits(const(char)*p, const uint max)
    {
        uint value;
        bool overflow;
        for (uint d; (d = uint(*p) - uint('0')) < 10; ++p)
        {
            import core.checkedint : mulu, addu;
            value = mulu(value, 10, overflow);
            value = addu(value, d, overflow);
        }
        return (overflow || value > max || *p) ? uint.max : value;
    }

    version (none)
    {
        for (size_t i = 0; i < arguments.dim; i++)
        {
            printf("arguments[%d] = '%s'\n", i, arguments[i]);
        }
    }
    for (size_t i = 1; i < arguments.dim; i++)
    {
        const(char)* p = arguments[i];
        if (*p == '-')
        {
            if (strcmp(p + 1, "allinst") == 0) // https://dlang.org/dmd.html#switch-allinst
                params.allInst = true;
            else if (strcmp(p + 1, "de") == 0) // https://dlang.org/dmd.html#switch-de
                params.useDeprecated = 0;
            else if (strcmp(p + 1, "d") == 0)  // https://dlang.org/dmd.html#switch-d
                params.useDeprecated = 1;
            else if (strcmp(p + 1, "dw") == 0) // https://dlang.org/dmd.html#switch-dw
                params.useDeprecated = 2;
            else if (strcmp(p + 1, "c") == 0)  // https://dlang.org/dmd.html#switch-c
                params.link = false;
            else if (memcmp(p + 1, cast(char*)"color", 5) == 0) // https://dlang.org/dmd.html#switch-color
            {
                params.color = true;
                // Parse:
                //      -color
                //      -color=on|off
                if (p[6] == '=')
                {
                    if (strcmp(p + 7, "off") == 0)
                        params.color = false;
                    else if (strcmp(p + 7, "on") != 0)
                        goto Lerror;
                }
                else if (p[6])
                    goto Lerror;
            }
            else if (memcmp(p + 1, cast(char*)"conf=", 5) == 0) // https://dlang.org/dmd.html#switch-conf
            {
                // ignore, already handled above
            }
            else if (memcmp(p + 1, cast(char*)"cov", 3) == 0) // https://dlang.org/dmd.html#switch-cov
            {
                params.cov = true;
                // Parse:
                //      -cov
                //      -cov=nnn
                if (p[4] == '=')
                {
                    if (isdigit(cast(char)p[5]))
                    {
                        const percent = parseDigits(p + 5, 100);
                        if (percent == uint.max)
                            goto Lerror;
                        params.covPercent = cast(ubyte)percent;
                    }
                    else
                        goto Lerror;
                }
                else if (p[4])
                    goto Lerror;
            }
            else if (strcmp(p + 1, "shared") == 0)
                params.dll = true;
            else if (strcmp(p + 1, "dylib") == 0)
            {
                static if (TARGET_OSX)
                {
                    Loc loc;
                    deprecation(loc, "use -shared instead of -dylib");
                    params.dll = true;
                }
                else
                {
                    goto Lerror;
                }
            }
            else if (strcmp(p + 1, "fPIC") == 0)
            {
                static if (TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
                {
                    params.pic = 1;
                }
                else
                {
                    goto Lerror;
                }
            }
            else if (strcmp(p + 1, "map") == 0) // https://dlang.org/dmd.html#switch-map
                params.map = true;
            else if (strcmp(p + 1, "multiobj") == 0)
                params.multiobj = true;
            else if (strcmp(p + 1, "g") == 0) // https://dlang.org/dmd.html#switch-g
                params.symdebug = 1;
            else if (strcmp(p + 1, "gc") == 0)  // https://dlang.org/dmd.html#switch-gc
            {
                Loc loc;
                deprecation(loc, "use -g instead of -gc");
                params.symdebug = 2;
            }
            else if (strcmp(p + 1, "gf") == 0)
            {
                if (!params.symdebug)
                    params.symdebug = 1;
                params.symdebugref = true;
            }
            else if (strcmp(p + 1, "gs") == 0)  // https://dlang.org/dmd.html#switch-gs
                params.alwaysframe = true;
            else if (strcmp(p + 1, "gx") == 0)  // https://dlang.org/dmd.html#switch-gx
                params.stackstomp = true;
            else if (strcmp(p + 1, "gt") == 0)
            {
                error("use -profile instead of -gt");
                params.trace = true;
            }
            else if (strcmp(p + 1, "m32") == 0) // https://dlang.org/dmd.html#switch-m32
            {
                params.is64bit = false;
                params.mscoff = false;
            }
            else if (strcmp(p + 1, "m64") == 0) // https://dlang.org/dmd.html#switch-m64
            {
                params.is64bit = true;
                static if (TARGET_WINDOS)
                {
                    params.mscoff = true;
                }
            }
            else if (strcmp(p + 1, "m32mscoff") == 0) // https://dlang.org/dmd.html#switch-m32mscoff
            {
                static if (TARGET_WINDOS)
                {
                    params.is64bit = 0;
                    params.mscoff = true;
                }
                else
                {
                    error("-m32mscoff can only be used on windows");
                }
            }
            else if (strncmp(p + 1, "mscrtlib=", 9) == 0)
            {
                static if (TARGET_WINDOS)
                {
                    params.mscrtlib = p + 10;
                }
                else
                {
                    error("-mscrtlib");
                }
            }
            else if (memcmp(p + 1, cast(char*)"profile", 7) == 0) // https://dlang.org/dmd.html#switch-profile
            {
                // Parse:
                //      -profile
                //      -profile=gc
                if (p[8] == '=')
                {
                    if (strcmp(p + 9, "gc") == 0)
                        params.tracegc = true;
                    else
                        goto Lerror;
                }
                else if (p[8])
                    goto Lerror;
                else
                    params.trace = true;
            }
            else if (strcmp(p + 1, "v") == 0) // https://dlang.org/dmd.html#switch-v
                params.verbose = true;
            else if (strcmp(p + 1, "vcg-ast") == 0)
                params.vcg_ast = true;
            else if (strcmp(p + 1, "vtls") == 0) // https://dlang.org/dmd.html#switch-vtls
                params.vtls = true;
            else if (strcmp(p + 1, "vcolumns") == 0) // https://dlang.org/dmd.html#switch-vcolumns
                params.showColumns = true;
            else if (strcmp(p + 1, "vgc") == 0) // https://dlang.org/dmd.html#switch-vgc
                params.vgc = true;
            else if (memcmp(p + 1, cast(char*)"verrors", 7) == 0) // https://dlang.org/dmd.html#switch-verrors
            {
                if (p[8] == '=' && isdigit(cast(char)p[9]))
                {
                    const num = parseDigits(p + 9, int.max);
                    if (num == uint.max)
                        goto Lerror;
                    params.errorLimit = num;
                }
                else if (memcmp(p + 9, cast(char*)"spec", 4) == 0)
                {
                    params.showGaggedErrors = true;
                }
                else
                    goto Lerror;
            }
            else if (memcmp(p + 1, "mcpu".ptr, 4) == 0) // https://dlang.org/dmd.html#switch-mcpu
            {
                // Parse:
                //      -mcpu=identifier
                if (p[5] == '=')
                {
                    if (strcmp(p + 6, "?") == 0)
                    {
                        params.mcpuUsage = true;
                        return false;
                    }
                    else if (Identifier.isValidIdentifier(p + 6))
                    {
                        const ident = p + 6;
                        switch (ident[0 .. strlen(ident)])
                        {
                        case "baseline":
                            params.cpu = CPU.baseline;
                            break;
                        case "avx":
                            params.cpu = CPU.avx;
                            break;
                        case "avx2":
                            params.cpu = CPU.avx2;
                            break;
                        case "native":
                            params.cpu = CPU.native;
                            break;
                        default:
                            goto Lerror;
                        }
                    }
                    else
                        goto Lerror;
                }
                else
                    goto Lerror;
            }
            else if (memcmp(p + 1, cast(char*)"transition", 10) == 0) // https://dlang.org/dmd.html#switch-transition
            {
                // Parse:
                //      -transition=number
                if (p[11] == '=')
                {
                    if (strcmp(p + 12, "?") == 0)
                    {
                        params.transitionUsage = true;
                        return false;
                    }
                    if (isdigit(cast(char)p[12]))
                    {
                        const num = parseDigits(p + 12, int.max);
                        if (num == uint.max)
                            goto Lerror;

                        // Bugzilla issue number
                        switch (num)
                        {
                        case 3449:
                            params.vfield = true;
                            break;
                        case 10378:
                            params.bug10378 = true;
                            break;
                        case 14488:
                            params.vcomplex = true;
                            break;
                        case 16997:
                            params.fix16997 = true;
                            break;
                        default:
                            goto Lerror;
                        }
                    }
                    else if (Identifier.isValidIdentifier(p + 12))
                    {
                        const ident = p + 12;
                        switch (ident[0 .. strlen(ident)])
                        {
                        case "all":
                            params.vtls = true;
                            params.vfield = true;
                            params.vcomplex = true;
                            break;
                        case "checkimports":
                            params.check10378 = true;
                            break;
                        case "complex":
                            params.vcomplex = true;
                            break;
                        case "field":
                            params.vfield = true;
                            break;
                        case "import":
                            params.bug10378 = true;
                            break;
                        case "intpromote":
                            params.fix16997 = true;
                            break;
                        case "tls":
                            params.vtls = true;
                            break;
                        default:
                            goto Lerror;
                        }
                    }
                    else
                        goto Lerror;
                }
                else
                    goto Lerror;
            }
            else if (strcmp(p + 1, "w") == 0)   // https://dlang.org/dmd.html#switch-w
                params.warnings = 1;
            else if (strcmp(p + 1, "wi") == 0)  // https://dlang.org/dmd.html#switch-wi
                params.warnings = 2;
            else if (strcmp(p + 1, "O") == 0)   // https://dlang.org/dmd.html#switch-O
                params.optimize = true;
            else if (p[1] == 'o')
            {
                const(char)* path;
                switch (p[2])
                {
                case '-':                       // https://dlang.org/dmd.html#switch-o-
                    params.obj = false;
                    break;
                case 'd':                       // https://dlang.org/dmd.html#switch-od
                    if (!p[3])
                        goto Lnoarg;
                    path = p + 3 + (p[3] == '=');
                    version (Windows)
                    {
                        path = toWinPath(path);
                    }
                    params.objdir = path;
                    break;
                case 'f':                       // https://dlang.org/dmd.html#switch-of
                    if (!p[3])
                        goto Lnoarg;
                    path = p + 3 + (p[3] == '=');
                    version (Windows)
                    {
                        path = toWinPath(path);
                    }
                    params.objname = path;
                    break;
                case 'p':                       // https://dlang.org/dmd.html#switch-op
                    if (p[3])
                        goto Lerror;
                    params.preservePaths = true;
                    break;
                case 0:
                    error("-o no longer supported, use -of or -od");
                    break;
                default:
                    goto Lerror;
                }
            }
            else if (p[1] == 'D')       // https://dlang.org/dmd.html#switch-D
            {
                params.doDocComments = true;
                switch (p[2])
                {
                case 'd':               // https://dlang.org/dmd.html#switch-Dd
                    if (!p[3])
                        goto Lnoarg;
                    params.docdir = p + 3 + (p[3] == '=');
                    break;
                case 'f':               // https://dlang.org/dmd.html#switch-Df
                    if (!p[3])
                        goto Lnoarg;
                    params.docname = p + 3 + (p[3] == '=');
                    break;
                case 0:
                    break;
                default:
                    goto Lerror;
                }
            }
            else if (p[1] == 'H')       // https://dlang.org/dmd.html#switch-H
            {
                params.doHdrGeneration = true;
                switch (p[2])
                {
                case 'd':               // https://dlang.org/dmd.html#switch-Hd
                    if (!p[3])
                        goto Lnoarg;
                    params.hdrdir = p + 3 + (p[3] == '=');
                    break;
                case 'f':               // https://dlang.org/dmd.html#switch-Hf
                    if (!p[3])
                        goto Lnoarg;
                    params.hdrname = p + 3 + (p[3] == '=');
                    break;
                case 0:
                    break;
                default:
                    goto Lerror;
                }
            }
            else if (p[1] == 'X')       // https://dlang.org/dmd.html#switch-X
            {
                params.doJsonGeneration = true;
                switch (p[2])
                {
                case 'f':               // https://dlang.org/dmd.html#switch-Xf
                    if (!p[3])
                        goto Lnoarg;
                    params.jsonfilename = p + 3 + (p[3] == '=');
                    break;
                case 0:
                    break;
                default:
                    goto Lerror;
                }
            }
            else if (strcmp(p + 1, "ignore") == 0)      // https://dlang.org/dmd.html#switch-ignore
                params.ignoreUnsupportedPragmas = true;
            else if (strcmp(p + 1, "property") == 0)
                params.enforcePropertySyntax = true;
            else if (strcmp(p + 1, "inline") == 0) // https://dlang.org/dmd.html#switch-inline
            {
                params.useInline = true;
                params.hdrStripPlainFunctions = false;
            }
            else if (strcmp(p + 1, "dip25") == 0)       // https://dlang.org/dmd.html#switch-dip25
                params.useDIP25 = true;
            else if (strcmp(p + 1, "dip1000") == 0)
            {
                params.useDIP25 = true;
                params.vsafe = true;
            }
            else if (strcmp(p + 1, "dip1008") == 0)
            {
                params.ehnogc = true;
            }
            else if (strcmp(p + 1, "lib") == 0) // https://dlang.org/dmd.html#switch-lib
                params.lib = true;
            else if (strcmp(p + 1, "nofloat") == 0)
                params.nofloat = true;
            else if (strcmp(p + 1, "quiet") == 0)
            {
                // Ignore
            }
            else if (strcmp(p + 1, "release") == 0) // https://dlang.org/dmd.html#switch-release
                params.release = true;
            else if (strcmp(p + 1, "betterC") == 0) // https://dlang.org/dmd.html#switch-betterC
                params.betterC = true;
            else if (strcmp(p + 1, "noboundscheck") == 0) // https://dlang.org/dmd.html#switch-noboundscheck
            {
                params.useArrayBounds = CHECKENABLE.off;
            }
            else if (memcmp(p + 1, cast(char*)"boundscheck", 11) == 0) // https://dlang.org/dmd.html#switch-boundscheck
            {
                // Parse:
                //      -boundscheck=[on|safeonly|off]
                if (p[12] == '=')
                {
                    if (strcmp(p + 13, "on") == 0)
                    {
                        params.useArrayBounds = CHECKENABLE.on;
                    }
                    else if (strcmp(p + 13, "safeonly") == 0)
                    {
                        params.useArrayBounds = CHECKENABLE.safeonly;
                    }
                    else if (strcmp(p + 13, "off") == 0)
                    {
                        params.useArrayBounds = CHECKENABLE.off;
                    }
                    else
                        goto Lerror;
                }
                else
                    goto Lerror;
            }
            else if (strcmp(p + 1, "unittest") == 0)
                params.useUnitTests = true;
            else if (p[1] == 'I') // https://dlang.org/dmd.html#switch-I
            {
                if (!params.imppath)
                    params.imppath = new Strings();
                params.imppath.push(p + 2 + (p[2] == '='));
            }
            else if (p[1] == 'm' && p[2] == 'v' && p[3] == '=') // https://dlang.org/dmd.html#switch-mv
            {
                if (p[4] && strchr(p + 5, '='))
                {
                    if (!params.modFileAliasStrings)
                        params.modFileAliasStrings = new Strings();
                    params.modFileAliasStrings.push(p + 4);
                }
                else
                    goto Lerror;
            }
            else if (p[1] == 'J') // https://dlang.org/dmd.html#switch-J
            {
                if (!params.fileImppath)
                    params.fileImppath = new Strings();
                params.fileImppath.push(p + 2 + (p[2] == '='));
            }
            else if (memcmp(p + 1, cast(char*)"debug", 5) == 0 && p[6] != 'l') // https://dlang.org/dmd.html#switch-debug
            {
                // Parse:
                //      -debug
                //      -debug=number
                //      -debug=identifier
                if (p[6] == '=')
                {
                    if (isdigit(cast(char)p[7]))
                    {
                        const level = parseDigits(p + 7, int.max);
                        if (level == uint.max)
                            goto Lerror;

                        params.debuglevel = level;
                    }
                    else if (Identifier.isValidIdentifier(p + 7))
                    {
                        if (!params.debugids)
                            params.debugids = new Array!(const(char)*);
                        params.debugids.push(p + 7);
                    }
                    else
                        goto Lerror;
                }
                else if (p[6])
                    goto Lerror;
                else
                    params.debuglevel = 1;
            }
            else if (memcmp(p + 1, cast(char*)"version", 7) == 0) // https://dlang.org/dmd.html#switch-version
            {
                // Parse:
                //      -version=number
                //      -version=identifier
                if (p[8] == '=')
                {
                    if (isdigit(cast(char)p[9]))
                    {
                        const level = parseDigits(p + 9, int.max);
                        if (level == uint.max)
                            goto Lerror;
                        params.versionlevel = level;
                    }
                    else if (Identifier.isValidIdentifier(p + 9))
                    {
                        if (!params.versionids)
                            params.versionids = new Array!(const(char)*);
                        params.versionids.push(p + 9);
                    }
                    else
                        goto Lerror;
                }
                else
                    goto Lerror;
            }
            else if (strcmp(p + 1, "-b") == 0)
                params.debugb = true;
            else if (strcmp(p + 1, "-c") == 0)
                params.debugc = true;
            else if (strcmp(p + 1, "-f") == 0)
                params.debugf = true;
            else if (strcmp(p + 1, "-help") == 0 || strcmp(p + 1, "h") == 0)
            {
                params.usage = true;
                return false;
            }
            else if (strcmp(p + 1, "-r") == 0)
                params.debugr = true;
            else if (strcmp(p + 1, "-version") == 0)
            {
                params.logo = true;
                return false;
            }
            else if (strcmp(p + 1, "-x") == 0)
                params.debugx = true;
            else if (strcmp(p + 1, "-y") == 0)
                params.debugy = true;
            else if (p[1] == 'L')       // https://dlang.org/dmd.html#switch-L
            {
                params.linkswitches.push(p + 2 + (p[2] == '='));
            }
            else if (memcmp(p + 1, cast(char*)"defaultlib=", 11) == 0) // https://dlang.org/dmd.html#switch-defaultlib
            {
                params.defaultlibname = p + 1 + 11;
            }
            else if (memcmp(p + 1, cast(char*)"debuglib=", 9) == 0)     // https://dlang.org/dmd.html#switch-debuglib
            {
                params.debuglibname = p + 1 + 9;
            }
            else if (memcmp(p + 1, cast(char*)"deps", 4) == 0) // https://dlang.org/dmd.html#switch-deps
            {
                if (params.moduleDeps)
                {
                    error("-deps[=file] can only be provided once!");
                    break;
                }
                if (p[5] == '=')
                {
                    params.moduleDepsFile = p + 1 + 5;
                    if (!params.moduleDepsFile[0])
                        goto Lnoarg;
                }
                else if (p[5] != '\0')
                {
                    // Else output to stdout.
                    goto Lerror;
                }
                params.moduleDeps = new OutBuffer();
            }
            else if (strcmp(p + 1, "main") == 0)        // https://dlang.org/dmd.html#switch-main
            {
                params.addMain = true;
            }
            else if (memcmp(p + 1, cast(char*)"man", 3) == 0)   // https://dlang.org/dmd.html#switch-man
            {
                params.manual = true;
                return false;
            }
            else if (strcmp(p + 1, "run") == 0)         // https://dlang.org/dmd.html#switch-run
            {
                params.run = true;
                size_t length = argc - i - 1;
                if (length)
                {
                    const(char)* ext = FileName.ext(arguments[i + 1]);
                    if (ext && FileName.equals(ext, "d") == 0 && FileName.equals(ext, "di") == 0)
                    {
                        error("-run must be followed by a source file, not '%s'", arguments[i + 1]);
                        break;
                    }
                    if (strcmp(arguments[i + 1], "-") == 0)
                        files.push("__stdin.d");
                    else
                        files.push(arguments[i + 1]);
                    params.runargs.setDim(length - 1);
                    for (size_t j = 0; j < length - 1; ++j)
                    {
                        params.runargs[j] = arguments[i + 2 + j];
                    }
                    i += length;
                }
                else
                {
                    params.run = false;
                    goto Lnoarg;
                }
            }
            else if (p[1] == '\0')
                files.push("__stdin.d");
            else
            {
            Lerror:
                error("unrecognized switch '%s'", arguments[i]);
                continue;
            Lnoarg:
                error("argument expected for switch '%s'", arguments[i]);
                continue;
            }
        }
        else
        {
            static if (TARGET_WINDOS)
            {
                const(char)* ext = FileName.ext(p);
                if (ext && FileName.compare(ext, "exe") == 0)
                {
                    params.objname = p;
                    continue;
                }
                if (strcmp(p, `/?`) == 0)
                {
                    params.usage = true;
                    return false;
                }
            }
            files.push(p);
        }
    }
    return errors;
}

