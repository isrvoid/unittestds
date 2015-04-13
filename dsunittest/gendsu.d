module dsunittest.gendsu;

import std.range;
import std.file;

void main(string args[])
{
    // refactor
    string[] paths = args[1 .. $];
    string[] contents = new string[paths.length];
    foreach (size_t i, path; paths)
        contents[i] = readText(path);

}

private:
void writeWarning(string filename, string msg)
{
    import std.stdio;
    stderr.writeln(filename, ": warning: ", msg);
}

string makeNoMatchMsg(string filename) pure nothrow @safe
{
    return filename ~ ": error: unterminated UNITTEST block";
}

struct UnittestFunctionFinder
{
    import std.regex;
    import std.range : empty;
    import util.commentBroom;

    private:

    string filename;
    bool blockNotFound;
    string remaining;

    public string[] names;


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

    public this(string s, string filename)
    {
        this.filename = filename;

        lastWarning = null;
        remaining = removeCommentsAndStrings(s);
        if (!lastWarning.empty)
            writeWarning(filename, lastWarning);

        // FIXME continue
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

        // FIXME count nested preprocessor conditionals
        auto capEnd = matchFirst(remaining, rEnd);
        if (capEnd.empty)
        {
            throw new NoMatchException(makeNoMatchMsg(filename));
        }
        remaining = capEnd.post;
        auto content = capEnd.pre;

        s = remaining;
        return content;
    }

    string[] findNames(string s)
    {
        return null;
    }
}

// UnittestFunctionFinder
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

