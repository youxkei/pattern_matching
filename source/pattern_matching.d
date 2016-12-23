module pattern_matching;

import std.conv : to;

import tcenal.dsl.generate_parsers : generateParsers;
import tcenal.d.lexer : lex;
import tcenal.d.parsers : Module;
import tcenal.rule_selector : createRuleSelector;
import tcenal.parser_combinator.parse_tree_node : ParseTreeNode;
import tcenal.parser_combinator.util : parseWithoutMemo;

mixin(generateParsers(
q{
    AggregateDeclaration <- CaseClassDeclaration / super
    CaseClassDeclaration <- "case" "class" @identifier "{" CaseClassConstructor*<","> ","? "}"
    CaseClassConstructor <- @identifier "(" (Type @identifier)*<","> ","? ")"

    PrimaryExpression <- CaseExpression / super
    CaseExpression <- "case" "(" Expression ")" "{" Case* "}"
    Case <- Pattern ":" Expression ";"
    Pattern <- @identifier ("(" Pattern*<","> ","? ")")? / PrimaryExpression
}));

string generateDlangCode(ParseTreeNode node)
{
    switch (node.ruleName)
    {
        case "CaseClassDeclaration":
        {
            string code = "class " ~ node.children[0].children[2].token.value ~ "{}";

            foreach (caseClassConstructor; node.children[0].children[4].children)
            {
                code ~=
                    "class " ~ caseClassConstructor.children[0].children[0].token.value ~ ":" ~ node.children[0].children[2].token.value ~"{"
                    q{this(typeof(this.tupleof) args) { this.tupleof = args; }}
                    q{static typeof(this) opCall(typeof(this.tupleof) args) { return new typeof(this)(args); }}
                ;

                foreach (field; caseClassConstructor.children[0].children[2].children)
                {
                    code ~= field.children[0].generateDlangCode() ~ " " ~ field.children[1].token.value ~ ";";
                }

                code ~= "}";
            }

            return code;
        }

        case "CaseExpression":
        {
            string code = "(){auto FOR_PATTERN_MATCHING_DONT_REFER_ME = " ~ node.children[0].children[2].generateDlangCode() ~ ";" ;

            foreach (case_; node.children[0].children[5].children)
            {
                code ~= case_.generateDlangCode();
            }

            code ~= "assert(0);}()";

            return code;
        }

        case "Case":
            return node.children[0].children[0].generateDlangCodeFromPattern("FOR_PATTERN_MATCHING_DONT_REFER_ME", "return " ~ node.children[0].children[2].generateDlangCode() ~ ";");

        default:
        {
            if (0 < node.ruleName.length) {
                string code;

                foreach (child; node.children)
                {
                    code ~= child.generateDlangCode();
                }

                return code;
            } else {
                return node.token.value ~ " ";
            }
        }
    }
}

string generateDlangCodeFromPattern(ParseTreeNode node, string matchingValue, string continuation)
{
    if (node.children[0].ruleName == "PrimaryExpression")
    {
        return "if (" ~ matchingValue ~ " == " ~ node.children[0].generateDlangCode() ~ ") {" ~ continuation ~ "}";
    }
    else if (node.children[0].children[1].children.length == 0)
    {
        if (node.children[0].children[0].token.value == "_")
        {
            return continuation;
        }
        else
        {
            return "auto " ~ node.children[0].children[0].token.value ~ " = " ~ matchingValue ~ ";" ~ continuation;
        }
    }
    else
    {
        string code = continuation;

        foreach_reverse (i, pattern; node.children[0].children[1].children[0].children[1].children)
        {
            code = pattern.generateDlangCodeFromPattern("(cast(" ~ node.children[0].children[0].token.value ~ ") " ~ matchingValue ~ ").tupleof[" ~ i.to!string ~ "]", code);
        }

        code = "if (cast(" ~ node.children[0].children[0].token.value ~ ") " ~ matchingValue ~ ") {" ~ code ~ "}";

        return code;
    }
}

alias parse = parseWithoutMemo!(Module!(createRuleSelector!().RuleSelector));

string PATTERN_MATCHING(string source)
{
    return source.lex().parse().node.generateDlangCode();
}
