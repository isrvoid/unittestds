module util.commentBroom;

import std.regex;
import std.algorithm.searching;
import std.range;

private:

class NoMatchException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @safe
    {
        super(msg, file, line, next);
    }
}

enum
{
    lineCommentStart = "//",
    pLineCommentStart = lineCommentStart,
    pLineCommentEnd = r"(?=\n|\r\n)", // let's deprecate single CR as line terminator

    blockCommentStart = "/*",
    pBlockCommentStart = r"/\*",
    pBlockCommentEnd = r"\*/",

    stringStart = `"`,
    pStringStart = stringStart,
    pStringEnd = `(?<!\\)(?:\\\\)*"`,

    pSomeStart = pLineCommentStart ~ "|" ~ pBlockCommentStart ~ "|" ~ pStringStart
}

enum
{
    rSomeStart = ctRegex!(pSomeStart),

    rLineCommentEnd = ctRegex!(pLineCommentEnd),
    rBlockCommentEnd = ctRegex!(pBlockCommentEnd),
    rStringEnd = ctRegex!(pStringEnd)
}

enum postErrorMsg = [lineCommentStart:"missing line terminator", blockCommentStart:"unterminated block comment",
                  stringStart:"unterminated string"];

/* Removes C-style comments and strings.
Block comments and strings are replaced with a space.
For simplicity, also removes unterminated block comment or string
at the end of the input (printing a warning).  */
public string removeCommentsAndStrings(string s) @safe
{
    import std.array : appender;
    auto app = appender!string();
    app.reserve(s.length);

    auto remaining = s;

    while (true)
    {
        auto cap = matchFirst(remaining, rSomeStart);
        if (cap.empty)
        {
            app.put(remaining);
            return app.data;
        }

        app.put(cap.pre);
        remaining = cap.post;

        bool isLineComment = (cap.hit == lineCommentStart);
        if (!isLineComment)
            app.put(' ');

        try
        {
            remaining = remaining.getPost(getEndRegex(cap.hit));
        }
        catch (NoMatchException)
        {
            remaining = remaining.getLineTerminatorAtBack();
        }
    }

    return app.data;
}

string getPost(RegEx)(string s, RegEx postRegex) @safe
if (is(RegEx == Regex!char) || is(RegEx == StaticRegex!char))
{
    auto cap = matchFirst(s, postRegex);
    if (cap.empty)
        throw new NoMatchException(null);

    return cap.post;
}

StaticRegex!char getEndRegex(string matchedStart) pure nothrow @safe
{
    if (matchedStart == lineCommentStart)
        return rLineCommentEnd;

    if (matchedStart == blockCommentStart)
        return rBlockCommentEnd;

    if (matchedStart == stringStart)
        return rStringEnd;

    assert(false);
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
        auto input = readText(filename);
        auto expectedOutput = readText(filename ~ verifyExtension);
        assert(input.removeCommentsAndStrings() == expectedOutput, filename);
    }
}