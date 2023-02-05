# Done by all things that want to perform some kind of effect at BEGIN time.
# They may do that effect before their children are visited in resolution or
# after; the default is after.
class RakuAST::BeginTime
  is RakuAST::Node
{
    has int $!begin-performed;

    # Method implemented by a node to perform its begin-time side-effects.
    method PERFORM-BEGIN(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context) {
        nqp::die('Missing PERFORM-BEGIN implementation in ' ~ self.HOW.name(self))
    }

    # Should the BEGIN-time effects be performed before or after the parse of
    # this node or both?
    method is-begin-performed-before-children() { False }
    method is-begin-performed-after-children() { !self.is-begin-performed-before-children }

    # Ensure the begin-time effects are performed.
    method ensure-begin-performed(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context, int :$phase) {
        if nqp::can(self, 'PERFORM-BEGIN-BEFORE-CHILDREN') || nqp::can(self, 'PERFORM-BEGIN-AFTER-CHILDREN') {
            if $phase == 0 && self.is-begin-performed-before-children || $phase == 1 {
                unless $!begin-performed +& 1 {
                    self.PERFORM-BEGIN-BEFORE-CHILDREN($resolver, $context);
                    nqp::bindattr_i(self, RakuAST::BeginTime, '$!begin-performed',  $!begin-performed +| 1);
                }
            }
            if $phase == 0 && self.is-begin-performed-after-children || $phase == 2 {
                unless $!begin-performed +& 2 {
                    self.PERFORM-BEGIN-AFTER-CHILDREN($resolver, $context);
                    nqp::bindattr_i(self, RakuAST::BeginTime, '$!begin-performed', $!begin-performed +| 2);
                }
            }
        }
        else {
            unless $!begin-performed {
                self.PERFORM-BEGIN($resolver, $context);
                nqp::bindattr_i(self, RakuAST::BeginTime, '$!begin-performed', 3);
            }
        }
        Nil
    }

    # Called when a BEGIN-time construct needs to evaluate code. Tries to
    # interpret simple things to avoid the cost of compilation.
    method IMPL-BEGIN-TIME-EVALUATE(RakuAST::Node $code, RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context) {
        $code.IMPL-CHECK($resolver, $context, False);
        if $code.IMPL-CAN-INTERPRET {
            $code.IMPL-INTERPRET(RakuAST::IMPL::InterpContext.new)
        }
        elsif nqp::istype($code, RakuAST::Code) {
            $code.meta-object()()
        }
        elsif nqp::istype($code, RakuAST::Expression) {
            my $thunk := RakuAST::ExpressionThunk.new;
            $code.wrap-with-thunk($thunk);
            $thunk.IMPL-STUB-CODE($resolver, $context);
            $thunk.IMPL-QAST-BLOCK($context, :expression($code));
            $thunk.meta-object()()
        }
        else {
            nqp::die('BEGIN time evaluation only supported for simple constructs so far')
        }
    }

    # Called when a BEGIN-time construct wants to evaluate a resolved code
    # with a set of arguments.
    method IMPL-BEGIN-TIME-CALL(RakuAST::Node $callee, RakuAST::ArgList $args,
            RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context) {
        if $callee.is-resolved && nqp::istype($callee.resolution, RakuAST::CompileTimeValue) &&
                $args.IMPL-CAN-INTERPRET {
            my $resolved := $callee.resolution.compile-time-value;
            my @args := $args.IMPL-INTERPRET(RakuAST::IMPL::InterpContext.new);
            my @pos := @args[0];
            my %named := @args[1];
            return $resolved(|@pos, |%named);
        }
        else {
            nqp::die('BEGIN time calls only supported for simple constructs so far')
        }
    }
}
