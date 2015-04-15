/*
Copyright:  Copyright Johannes Teichrieb 2015
License:    opensource.org/licenses/MIT
*/
module unittestds.gendsu;

import std.range : empty;
import std.array;
import std.file;
import std.regex;
import std.stdio : writeln;

import util.commentBroom;

int main(string args[])
{
    version (unittest)
        return 0;

    // refactor
    string[] paths = args[1 .. $];
    if (paths.empty)
    {
        writeln("gendsu: error: no input files");
        return -1;
    }
    string[] contents = new string[paths.length];
    foreach (size_t i, path; paths)
        contents[i] = readText(path);

    return 0;
}

enum runnerTemplate = import("unittestRunnerTemplate.c");

string makeMissingBlockTerminatorMsg(string filename) pure nothrow @safe
{
    return filename ~ ": error: UNITTEST block is missing #endif";
}

struct UnittestFunctionFinder
{
    public string[] funcNames;
    string file;

    private:

    bool blockNotFound;
    string remaining;


    version (unittest)
    {
        public this(string s)
        {
            remaining = s;
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
        remaining = removeCommentsAndStrings(s);
        if (!lastWarning.empty)
            writeln(file, ": warning: ", lastWarning);

        auto blocks = getBlocks();
        funcNames = getNames(blocks);
    }

    string getBlocks() @safe
    {
        auto app = appender!string();
        do
        {
            app.put(getNextBlock(remaining));
        }
        while (!blockNotFound);

        return app.data;
    }

    string getNextBlock(ref string s) @safe
    {
        enum
        {
            pStart = r"#\s*if(?:def|\s+defined)\s+UNITTEST",
            pEnd = r"#\s*endif",
            rStart = ctRegex!(pStart),
            rEnd = ctRegex!(pEnd)
        }

        auto capStart = matchFirst(s, rStart);
        if (capStart.empty)
        {
            blockNotFound = true;
            return null;
        }
        auto remaining = capStart.post;

        // FIXME traverse nested preprocessor conditionals
        auto capEnd = matchFirst(remaining, rEnd);
        if (capEnd.empty)
        {
            throw new NoMatchException(makeMissingBlockTerminatorMsg(file));
        }
        remaining = capEnd.post;
        auto content = capEnd.pre;

        s = remaining;
        return content;
    }

    string[] getNames(string s) @safe
    {
        enum
        {
            pFunc = r"(?<!static\s+)int\s+(?P<name>\w+)\s*\(\s*(?:void){0,1}\s*\)\s*\{",
            rFunc = ctRegex!(pFunc)
        }

        auto app = appender!(string[])();
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
        pluginApp = pluginApp.init;

        putFunctionDeclarations();
        newline();

        putLine("#define _UNITTEST_COUNT");
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
        putLine("static const _unittest_functions[] = {");

        putFunctionLiterals();
        newline();

        putLine("};");
    }

    void putFunctionLiterals() pure nothrow @safe
    {
        enum approxLineWidth = 100;
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
            pluginApp.put("{");
            pluginApp.put(func.name);
            pluginApp.put(`,"`);
            pluginApp.put(func.name);
            pluginApp.put(`()","`);
            pluginApp.put(func.file);
            pluginApp.put(`"},`);

            lineLength += func.name.length * 2 + func.file.length + syntaxOverheadLength;
            if (lineLength > approxLineWidth)
                startNewLine();
        }
    }

    void putLine(string s) pure nothrow @safe
    {
        pluginApp.put(s);
        newline();
    }

    void newline() pure nothrow @safe
    {
        import std.ascii;
        pluginApp.put(newline);
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
    auto pm = PluginMaker();
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
