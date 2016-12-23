import pattern_matching : PATTERN_MATCHING;

mixin(PATTERN_MATCHING(
q{
    import std.stdio;

    case class Expr {
        Number(int number),
        UnOp(string op, Expr expr),
        BinOp(string op, Expr lhs, Expr rhs),
    }

    int eval(Expr e)
    {
        return case (e) {
            Number(n): n;
            UnOp("-", operand): -operand.eval();
            BinOp("+", lhs, rhs): lhs.eval() + rhs.eval();
            BinOp("-", lhs, rhs): lhs.eval() - rhs.eval();
        };
    }

    void main()
    {
        BinOp("-", Number(33), Number(4)).eval().writeln();
        BinOp("+", Number(50), UnOp("-", Number(-7))).eval().writeln();
    }
}));
