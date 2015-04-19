/*
Copyright:  Copyright Johannes Teichrieb 2015
License:    opensource.org/licenses/MIT
*/
module unittestds.gendsu;

import std.range : empty;
import std.array : Appender;
import std.regex;
import std.stdio : writeln;

import util.commentBroom;

int main(string args[])
{
    import std.file : read, write;

    version (unittest)
        return 0;

    auto parsedArgs = ArgumentParser(args[1 .. $]);
    if (!parsedArgs.errors.empty)
    {
        foreach (error; parsedArgs.errors)
            writeln("gendsu: error: ", error);

        return -1;
    }

    string[] contents = new string[parsedArgs.files.length];
    foreach (size_t i, file; parsedArgs.files)
        contents[i] = cast(string) read(file);

    PluginMaker pm;
    foreach (size_t i, file; parsedArgs.files)
    {
        auto ff = UnittestFunctionFinder(contents[i], file);
        pm.putFunc(ff.funcNames, ff.file);
    }
    pm.makePlugin();

    auto runner = insertPlugin(runnerTemplate, pm.plugin);
    write(parsedArgs.outputFile, runner);

    return 0;
}

struct ArgumentParser
{
    private Appender!(string[]) fileApp;
    private enum outputFileSwitch = "-of";

    string[] errors;

    string outputFile = "unittestRunner.c";

    @disable this();

    this(string[] args) pure nothrow @safe
    {
        foreach (arg; args)
        {
            bool isFile = (arg[0] != '-');
            if (isFile)
                fileApp.put(arg);
            else
                handleSwitch(arg);
        }

        if (files.empty)
            errors ~= "no input files";
    }

    @property string[] files() pure nothrow @safe
    {
        return fileApp.data;
    }

    private:

    void handleSwitch(string arg) pure nothrow @safe
    {
        import std.algorithm : startsWith;

        if (arg.startsWith(outputFileSwitch))
            handleOutputFileSwitch(arg);
        else
            errors ~= "unrecognized switch '" ~ arg ~ "'";
    }

    void handleOutputFileSwitch(string arg) pure nothrow @safe
    {
        auto outputFile = arg[outputFileSwitch.length .. $];
        if (outputFile.empty)
        {
            errors ~= "argument expected for switch '" ~ outputFileSwitch ~ "'";
            return;
        }

        this.outputFile = outputFile;
    }
}

enum runnerTemplate = import("unittestRunnerTemplate.c");

struct UnittestFunctionFinder
{
    string[] funcNames;
    string file;

    private:

    bool blockNotFound;
    string loaf;


    version (unittest)
    {
        public this(string s)
        {
            loaf = s;
        }
    }
    else
    {
        @disable this();
    }

    public this(string s, string file) @safe
    {
        this.file = file;

        lastWarning = null;
        loaf = removeCommentsAndStrings(s);
        if (!lastWarning.empty)
            writeln(file, ": warning: ", lastWarning);

        auto blocks = getBlocks();
        funcNames = getNames(blocks);
    }

    string getBlocks() @safe
    {
        Appender!string app;
        do
        {
            app.put(getNextBlock(loaf));
        }
        while (!blockNotFound);

        return app.data;
    }

    string getNextBlock(ref string s) @trusted
    {
        enum rStart = ctRegex!(r"#\s*if(?:def|\s+defined)\s+UNITTEST");
        enum rPushPop = ctRegex!(r"#\s*(?:(if)|(endif))");
        enum popIndex = 2;

        auto cap = matchFirst(s, rStart);
        if (cap.empty)
        {
            blockNotFound = true;
            return null;
        }

        auto loaf = cap.post;
        auto contentStart = loaf.ptr;

        size_t stack = 1;
        while (stack)
        {
            cap = matchFirst(loaf, rPushPop);
            if (cap.empty)
                throw new NoMatchException(file ~ ": error: UNITTEST block is missing #endif");

            loaf = cap.post;

            if (!cap[popIndex].empty)
                --stack;
            else // push
                ++stack;
        }

        auto contentLength = cap.hit.ptr - contentStart;

        s = loaf;
        return contentStart[0 .. contentLength];
    }

    string[] getNames(string s) @safe
    {
        enum
        {
            pFunc = r"(?<!static\s+)int\s+(?P<name>\w+)\s*\(\s*(?:void){0,1}\s*\)\s*\{",
            rFunc = ctRegex!(pFunc)
        }

        Appender!(string[]) app;
        auto rm = matchAll(s, rFunc);
        while (!rm.empty)
        {
            auto cap = rm.front;
            rm.popFront();
            app.put(cap["name"]);
        }

        return app.data;
    }
}

struct PluginMaker
{
    private:
    Appender!(Func[]) funcApp;
    Appender!string pluginApp;

    struct Func
    {
        string name;
        string file;
    }

    public void putFunc(string[] names, string file) pure nothrow @safe
    {
        foreach (name; names)
            funcApp.put(Func(name, file));
    }

    public string makePlugin() pure nothrow @safe
    {
        import std.conv : text;

        pluginApp = pluginApp.init;

        putFunctionDeclarations();
        newline();

        putLine(text("#define _UNITTEST_COUNT ", functions.length));
        newline();

        putFunctionArray();

        return plugin;
    }

    public string plugin() pure nothrow @safe
    {
        return pluginApp.data;
    }

    void putFunctionDeclarations() pure nothrow @safe
    {
        foreach (func; functions)
        {
            pluginApp.put("int ");
            pluginApp.put(func.name);
            pluginApp.put("(void);");
            newline();
        }
    }

    void putFunctionArray() pure nothrow @safe
    {
        putLine("static const _unittest_func_t _unittest_functions[] = {");

        putFunctionLiterals();
        newline();

        pluginApp.put("};");
    }

    void putFunctionLiterals() pure nothrow @safe
    {
        enum softLineWidth = 100;
        enum syntaxOverheadLength = `{,"()",""},`.length;
        enum lineIndent = "    ";

        size_t lineLength = lineIndent.length;

        void startNewLine() pure nothrow @safe
        {
            newline();
            pluginApp.put(lineIndent);
            lineLength = lineIndent.length;
        }

        pluginApp.put(lineIndent);

        foreach (func; functions)
        {
            if (lineLength > softLineWidth)
                startNewLine();

            pluginApp.put("{");
            pluginApp.put(func.name);
            pluginApp.put(`,"`);
            pluginApp.put(func.name);
            pluginApp.put(`()","`);
            pluginApp.put(func.file);
            pluginApp.put(`"},`);

            lineLength += func.name.length * 2 + func.file.length + syntaxOverheadLength;
        }
    }

    void putLine(string s) pure nothrow @safe
    {
        pluginApp.put(s);
        newline();
    }

    void newline() pure nothrow @safe
    {
        pluginApp.put("\n");
    }

    Func[] functions() pure nothrow @safe
    {
        return funcApp.data;
    }
}

string insertPlugin(string tmpl, string plugin) @safe
{
    enum r = ctRegex!(".*@unittest_plugin.*");
    auto cap = matchFirst(tmpl, r);
    if (cap.empty)
        throw new NoMatchException("input is missing @unittest_plugin tag");

    return cap.pre ~ plugin ~ cap.post;
}

// ArgumentParser
unittest
{
    auto args = ["foo", "bar"];
    auto ap = ArgumentParser(args);
    assert(ap.errors.empty);
    assert(ap.files == args);
    assert(ap.outputFile == "unittestRunner.c");
}

unittest
{
    auto ap = ArgumentParser(["foo", "-offun.c", "bar"]);
    assert(ap.errors.empty);
    assert(ap.files == ["foo", "bar"]);
    assert(ap.outputFile == "fun.c");
}

unittest
{
    // no input files
    auto ap = ArgumentParser(null);
    assert(ap.errors.length == 1);
    assert(ap.errors[0] == "no input files");
}

version (unittest)
{
    bool checkUnknownSwitchError(string error, string us)
    {
        return error == "unrecognized switch '" ~ us ~ "'";
    }
}

unittest
{
    // unknown switch
    auto ap = ArgumentParser(["-hithere", "foo"]);
    assert(ap.errors.length == 1);
    assert(checkUnknownSwitchError(ap.errors[0], "-hithere"));
}

unittest
{
    // no input files and unknown switches
    auto ap = ArgumentParser(["-theQuick", "-brownFox"]);
    assert(ap.errors.length == 3);
    assert(checkUnknownSwitchError(ap.errors[0], "-theQuick"));
    assert(checkUnknownSwitchError(ap.errors[1], "-brownFox"));
    assert(ap.errors[2] == "no input files");
}

unittest
{
    // missing switch argument
    auto ap = ArgumentParser(["foo", "-of"]);
    assert(ap.errors.length == 1);
    assert(ap.errors[0] == "argument expected for switch '-of'");
    assert(ap.outputFile == "unittestRunner.c");
}

// UnittestFunctionFinder
unittest
{
    enum s = "int foo(void) { }
#ifdef UNITTEST
        int/* the quick*/__fun42 ( void  )  {  }
        static // brown fox
        int  gun() { }
#endif
        int bar() { }
#ifdef UNITTEST
        /* jumps over */int  
            hun  
            (
             /* the lazy dog */  ){}
#endif  ";

    auto ff = UnittestFunctionFinder(s, "dummy");
    assert(ff.funcNames == ["__fun42", "hun"]);
}

unittest
{
    // UNITTEST block without closing #endif throws exception
    enum s = "#ifdef UNITTEST
        // empty
        ";
    bool exceptionCaught;
    try
        auto ff = UnittestFunctionFinder(s, "dummy");
    catch (NoMatchException)
        exceptionCaught = true;

    assert(exceptionCaught);
}

    // getNextBlock
    // assumes that comments and strings were removed
    // i.e. the input doesn't contain "#ifdef" or /* #ifdef */
unittest
{
    // there is no point in ensuring certain whitespaces
    // the preprocessor will check for correctness
    auto singleBlock = "# ifdef  UNITTESTfoo#  endifbar";
    UnittestFunctionFinder ff;
    assert(ff.getNextBlock(singleBlock) == "foo");
    assert(singleBlock == "bar");
}

unittest
{
    auto notABlock = "foo bar";
    UnittestFunctionFinder ff;
    assert(ff.getNextBlock(notABlock) == null);
    assert(ff.blockNotFound);
    assert(notABlock == "foo bar");
}

unittest
{
    auto missingEndif = "#ifdef UNITTEST\n#  ifdef FOO\n#endif";
    UnittestFunctionFinder ff;
    bool exceptionCaught;
    try
        ff.getNextBlock(missingEndif);
    catch (NoMatchException)
        exceptionCaught = true;

    assert(exceptionCaught);
}

unittest
{
    auto emptyContent = "# if  defined   UNITTEST#  endiffun";
    UnittestFunctionFinder ff;
    assert(ff.getNextBlock(emptyContent).empty);
    assert(emptyContent == "fun");
}

unittest
{
    enum start = "#   ifdef  UNITTEST";
    enum end = "#   endif";
    enum post = "\nfoo bar";
    enum content = "\n the\n # if  defined FOO\n quick\n#if FUN\n brown\n #endif\n\n #else  \n
        fox\n\n  #if BAR\n jumps\n #  elif\n over\n # else\n the\n #endif\n lazy\n #endif\n dog\n ";
    auto loaf = start ~ content ~ end ~ post;

    UnittestFunctionFinder ff;
    assert(ff.getNextBlock(loaf) == content);
    assert(loaf == post);
}

    // getBlocks
unittest
{
    enum blocks = "#ifdef UNITTESTfun#endif don't care #  ifdef UNITTEST gun#endif";
    UnittestFunctionFinder ff = blocks;
    assert(ff.getBlocks() == "fun gun");
}

    // getNames
unittest
{
    enum names = "
        int  _foo1   (   )    { }
        static int bar() { }
        int fun(void  ){}
        int  hun_3(  void)  { } ";

    UnittestFunctionFinder ff;
    assert(ff.getNames(names) == ["_foo1", "fun", "hun_3"]);
}

// PluginMaker
    // putFunc
unittest
{
    PluginMaker pm;
    pm.putFunc(["fooFunc", "barFunc"], "funFile");
    assert(pm.functions.length == 2);
    auto func = pm.functions[1];
    assert(func.name == "barFunc");
    assert(func.file == "funFile");
}

// insertPlugin
unittest
{
    enum tmpl = "foo\n // @unittest_plugin don't care\nhun";
    assert(insertPlugin(tmpl, "fun") == "foo\nfun\nhun");
}

unittest
{
    // exception is thrown if @unittest_plugin is missing
    bool exceptionCaught;
    try
        insertPlugin("input with missing tag", "foo");
    catch (NoMatchException)
        exceptionCaught = true;

    assert(exceptionCaught);
}
