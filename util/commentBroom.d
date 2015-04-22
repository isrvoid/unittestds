/*
Copyright:  Copyright Johannes Teichrieb 2015
License:    opensource.org/licenses/MIT
*/
module util.commentBroom;

import std.regex;
import std.algorithm.searching;
import std.range;

class NoMatchException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @safe
    {
        super(msg, file, line, next);
    }
}

private:
enum lineCommentStart = "//";
enum blockCommentStart = "/*";
enum stringStart = `"`;

enum missingTerminatorWarnings = [lineCommentStart:"missing line terminator",
                               blockCommentStart:"unterminated block comment",
                               stringStart:"unterminated string"];

public string lastWarning;

/* Removes C-style comments and strings to allow easier parsing of source files.
Block comments are replaced with a space.
Strings are replaced with given argument.
For simplicity, also removes unterminated block comment or string
at the end of the input (printing a warning).  */
public string removeCommentsAndStrings(string strReplacement = " s ")(string s) @trusted
{
    import std.array : Appender;
    Appender!string app;
    app.reserve(s.length);

    auto loaf = s;

    while (true)
    {
        auto start = loaf.findNextStart();
        if (start.empty)
        {
            app.put(loaf);
            return app.data;
        }

        auto preStart = loaf[0 .. start.ptr - loaf.ptr];
        app.put(preStart);

        auto postStart = loaf[start.ptr - loaf.ptr + start.length .. $];
        loaf = postStart;

        app.put(getReplacement!strReplacement(start));

        try
        {
            loaf = getPostFunction(start)(loaf);
        }
        catch (NoMatchException)
        {
            lastWarning = missingTerminatorWarnings[start];
            loaf = loaf.getLineTerminatorAtBack();
        }
    }

    return app.data;
}

static immutable bool[0x100] isCharOfInterest;
static this()
{
    isCharOfInterest[cast(size_t) '/'] = true;
    isCharOfInterest[cast(size_t) '"'] = true;
}

string findNextStart(string loaf)
{
    size_t i;
    while (i < loaf.length)
    {
        if (isCharOfInterest[cast(size_t) loaf[i]])
        {
            loaf = loaf[i .. $];
            if (loaf[0] == '"')
                return loaf[0 .. 1];

            if (loaf.length >= 2 && (loaf[1] == '/' || loaf[1] == '*'))
                return loaf[0 .. 2];

            i = 0;
        }
        i++;
    }

    return null;
}

string getReplacement(string strReplacement)(string matchedStart)
{
    if (matchedStart == lineCommentStart)
        return "";

    if (matchedStart == blockCommentStart)
        return " ";

    if (matchedStart == stringStart)
        return strReplacement;

    assert(0);
}

string getPost(RegEx)(string s, RegEx postRegex) @safe
if (is(RegEx == Regex!char) || is(RegEx == StaticRegex!char))
{
    auto cap = matchFirst(s, postRegex);
    if (cap.empty)
        throw new NoMatchException(null);

    return cap.post;
}

string function(string) getPostFunction(string matchedStart) pure nothrow @safe
{
    if (matchedStart == lineCommentStart)
        return &postLineComment;

    if (matchedStart == blockCommentStart)
        return &postBlockComment;

    if (matchedStart == stringStart)
        return &postString;

    assert(0);
}

// single CR as line terminator is not supported
string postLineComment(string s) @trusted
{
    auto hit = s.find('\n');
    if (hit.empty)
        throw new NoMatchException(null);

    bool isLfPrecededByCr = hit.ptr > s.ptr && hit.ptr[-1] == '\r';
    if (!isLfPrecededByCr)
        return hit;
    else
        return (hit.ptr - 1)[0 .. hit.length + 1];
}

string postBlockComment(string s)
{
    auto hit = s.find("*/");
    if (hit.empty)
        throw new NoMatchException(null);

    return hit[2 .. $];
}

string postString(string s) @trusted
{
    auto loaf = s;
    while (true)
    {
        auto hit = loaf.find('"');
        if (hit.empty)
            throw new NoMatchException(null);

        bool isQmPrecededByBackslash = hit.ptr > s.ptr && hit.ptr[-1] == '\\';
        if (getPrecedingBackslashCount(loaf, hit.ptr) % 2 == 0)
            return hit[1 .. $];
        else
            loaf = hit[1 .. $];
    }
}

auto getPrecedingBackslashCount(string s, immutable(char)* cp) pure nothrow @trusted
{
    size_t count = 0;
    while (s.ptr < cp && *(--cp) == '\\')
        ++count;

    return count;
}

string getLineTerminatorAtBack(string s) pure nothrow @safe
{
    if (s.endsWith("\r\n"))
        return "\r\n";

    if (s.endsWith("\n"))
        return "\n";

    return null;
}

// removeCommentsAndStrings
version (unittest)
{
    import std.file;
    import std.stdio;

    enum verifyExtension = "_expected";

    string[] getTestInputFilenames()
    {
        string[] result;
        enum testFilesDir = "test/removeCommentsAndStrings";
        foreach (DirEntry de; dirEntries(testFilesDir, SpanMode.depth, false))
            if (de.isFile && !de.name.endsWith(verifyExtension))
                result ~= de.name;

        return result;
    }
}

unittest
{
    foreach (filename; getTestInputFilenames()) {
        auto input = cast(string) read(filename);
        auto expectedOutput = readText(filename ~ verifyExtension);
        assert(input.removeCommentsAndStrings!" "() == expectedOutput, filename);
    }
}
