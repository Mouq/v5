
my $INPUT_RECORD_SEPARATOR = "\n";
my $SUBSCRIPT_SEPARATOR    = chr(28);
my $VERSION_MAJOR          = 5;  # well, we have to say something
my $VERSION_MINOR          = 16;
my $VERSION_PATCH          = 0;
my $VERSION_V              = "v$VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH";
my $VERSION_FLOAT          = $VERSION_MAJOR + $VERSION_MINOR/1000 + $VERSION_PATCH/1000000;
my $OUTPUT_AUTOFLUSH       = 0;
my $OUTPUT_AUTOFLUSH_P    := Proxy.new(
    FETCH => method ()   { $OUTPUT_AUTOFLUSH },
    STORE => method ($n) { $OUTPUT_AUTOFLUSH = $n; try $*OUT.autoflush( ?$n ); } # XXX there is no IO::Handle.autoflush (yet)
);
my $CHILD_ERROR;
my $FORMAT_TOP_NAME;
my $SYSTEM_FD_MAX;
my $INPLACE_EDIT;
my $BASETIME;
my $LAST_SUBMATCH_RESULT;
my $LAST_REGEXP_CODE_RESULT;
my $ACCUMULATOR;
my $FORMAT_FORMFEED;
my $EXTENDED_OS_ERROR;
my $EXCEPTIONS_BEING_CAUGHT;
my $WARNING;
my $COMPILING;
my $DEBUGGING;
my $PERLDB;

class STDIN {
}
class STDOUT {
    method say  (*@a) { $*OUT.say(   join('', @a) ) }
    method print(*@a) { $*OUT.print( join('', @a) ) }
}
class STDERR {
    method say  (*@a) { $*ERR.say(   join('', @a) ) }
    method print(*@a) { $*ERR.print( join('', @a) ) }
}

sub EXPORT(|) {
    my %ex;
    %ex<STDIN>                    := STDIN;
    %ex<STDOUT>                   := STDOUT;
    %ex<STDERR>                   := STDERR;
    %ex<%ENV>                     := %*ENV;
    %ex<@INC>                     := %*CUSTOM_LIB<Perl5>;
    %ex<$$>                       := $*PID;
    %ex<$]>                       := $VERSION_FLOAT;
    %ex<$;>                       := $SUBSCRIPT_SEPARATOR;
    %ex<$|>                       := $OUTPUT_AUTOFLUSH_P;
    %ex<$?>                       := $CHILD_ERROR;

    %ex<$^>                       := $FORMAT_TOP_NAME;
    %ex<$^O>                      := $*OS;
    %ex<$^F>                      := $SYSTEM_FD_MAX;
    %ex<$^I>                      := $INPLACE_EDIT;
    %ex<$^T>                      := $BASETIME;
    %ex<$^V>                      := $VERSION_V;
    %ex<$^X>                      := $*EXECUTABLE_NAME;
    %ex<$^M>                       = Mu;
        
    ## Variables related to regular expressions
    %ex<$^N>                      := $LAST_SUBMATCH_RESULT;
    %ex<$^R>                      := $LAST_REGEXP_CODE_RESULT;
        
    ## Variables related to formats
    %ex<$^A>                      := $ACCUMULATOR;
    %ex<$^L>                      := $FORMAT_FORMFEED;
        
    ## Error Variables
    %ex<$^E>                      := $EXTENDED_OS_ERROR;
    %ex<$^S>                      := $EXCEPTIONS_BEING_CAUGHT;
    %ex<$^W>                      := $WARNING;
        
    ## Variables related to the interpreter state
    %ex<$^C>                      := $COMPILING;
    %ex<$^D>                      := $DEBUGGING;
    %ex<$^H>                      := Mu;
    %ex<%^H>                      := Mu;
    %ex<$^P>                      := $PERLDB;

    # Because Perl6 already has variables like $/ and $! built in, we can't ex-/import them directly.
    # So we need an accessor, the grammar token '$/' can use, and a way to support the English module.
    # I choosed $*-vars, because they can't be used from Perl5 directly because of its grammar.
    %ex<$*INPUT_RECORD_SEPARATOR> := $INPUT_RECORD_SEPARATOR;

    %ex
}

multi sub chop()          is export { chop(CALLER::DYNAMIC::<$_>) }
multi sub chop(*@s is rw) is export {
    my $chopped_of = '';
    for @s -> $s is rw {
        if $s && $s.chars {
            $chopped_of = $s.substr(*-1);
            $s          = $s.substr(0, *-1);
        }
    }
    $chopped_of
}

# http://perldoc.perl.org/functions/chomp.html
multi sub chomp()          is export { chomp(CALLER::DYNAMIC::<$_>) }
multi sub chomp(*@s is rw) is export {
    my $nr_chomped = 0;
    return 0 unless $INPUT_RECORD_SEPARATOR.defined;
    # TODO When in slurp mode ($/ = undef ) or fixed-length record mode
    #      ($/ is a reference to an integer or the like; see perlvar) chomp() won't remove anything
    for @s -> $s is rw {
        if $s && $s.chars {
            my $chomped  = $INPUT_RECORD_SEPARATOR eq ''
                        ?? $s.subst(/\n+$/, '')
                        !! $s.subst(/$INPUT_RECORD_SEPARATOR$/, '');
            $nr_chomped += $s.chars - $chomped.chars;
            $s           = $chomped;
        }
    }
    $nr_chomped
}

multi sub open( $fh is rw, $expr )             is export { open( $fh, $expr.substr(0, 1), $expr.substr(1) ) }
multi sub open( $fh is rw, $m, $expr, *@list ) is export {
    # ($path, :r(:$r), :w(:$w), :a(:$a), :p(:$p), :bin(:$bin), :chomp(:$chomp) = { ... }, :enc(:encoding(:$encoding)) = { ... })
    $fh = $expr.IO.open( :r($m eq '<'), :w($m eq '>'), :a($m eq '>>'), :p($m eq '|'), :bin(0) );
}

sub close( IO::Handle $fh ) is export { $fh.close }

sub ref($o) is export {
    $o.^name.uc
}

sub exists( \a ) is export { a:exists ?? 1 !! '' }

# http://perldoc.perl.org/functions/undef.html
multi sub undef()         is export { Nil              }
multi sub undef($a is rw) is export { undefine $a; Nil }

multi prefix:<P5+>(\a)     is export { a.P5Numeric }
multi infix:<P5+>(*@a)     is export { [+]  map { &prefix:<P5+>($_) }, @a }
multi infix:<P5==>(*@a)    is export { [==] map { &prefix:<P5+>($_) }, @a }
multi infix:<P5!=>(*@a)    is export { [!=] map { &prefix:<P5+>($_) }, @a }

multi prefix:<P5~>(\a)     is export { a.P5Str }
multi infix:<P5~>(*@a)     is export { [~] map { &prefix:<P5~>($_) }, @a }
multi infix:<|=> (\a, \b)  is export { a = a +& b        }
multi infix:<&=> (\a, \b)  is export { a = a +| b        }
multi infix:<||=>(\a, \b)  is rw is export { a = b unless a; a }
multi infix:<&&=>(\a, \b)  is rw is export { a = b if a; a     }
multi infix:<+=> (\a, \b)  is export { a = a.P5Numeric + b.P5Numeric }
multi infix:<-=> (\a, \b)  is export { a = a.P5Numeric - b.P5Numeric }
multi infix:<*=> (\a, \b)  is export { a = a.P5Numeric * b.P5Numeric }
multi infix:</=> (\a, \b)  is export { a = a.P5Numeric / b.P5Numeric }
multi infix:<P5/> (\a, \b) is export { a.P5Numeric / b.P5Numeric }
multi infix:<P5&> (Str \a, Str \b) is export { a ~& b }
multi infix:<P5&> (*@a)    is export { [+&] map { &prefix:<P5+>($_) }, @a }

multi trait_mod:<is>(Routine:D $r, :$lvalue!) is export {
    $r.set_rw();
}

use Perl5::warnings ();
use MONKEY_TYPING;

sub _P5do( $file ) is hidden_from_backtrace {
    my $ret;
    if $file {
        if $file.IO.e {
            try {
                $ret = eval slurp $file;
                CATCH {
                    default { warn(CALLER::DYNAMIC::<$!> = .Str) }
                }
            }
        }
    }
    else {
        die 'Null filename used'
    }
    $ret
}

augment class Any {
    method P5Str(Any:) is hidden_from_backtrace {
        if warnings::enabled('all') || warnings::enabled('uninitialized') {
            warn 'Use of uninitialized value in string'
        }
        ''
    }
    method P5Numeric(Any:) { 0 }
    method P5do(Any:) is hidden_from_backtrace { _P5do(self) }
    method P5scalar(Any:) { '' }
    method P5ord(Str:) { 0 }
}

augment class Nil {
    method P5Str(Nil:U:) is hidden_from_backtrace {
        if warnings::enabled('all') || warnings::enabled('uninitialized') {
            warn 'Use of uninitialized value in string'
        }
        ''
    }
    method P5Numeric(Nil:) { 0 }
    method P5do(Nil:) is hidden_from_backtrace { _P5do(self) }
    method P5scalar(Nil:) { Nil }
}

augment class Bool {
    multi method P5Str(Bool:U:) { '' }
    multi method P5Str(Bool:D:) { ?self ?? 1 !! '' }
    method P5Numeric(Bool:) { ?self ?? 1 !! 0 }
    method P5scalar(Bool:) { self.P5Str }
}

augment class Array {
    multi method P5Str(Array:U:) { '' }
    multi method P5Str(Array:D:) { join '', map { $_.defined ?? $_.P5Str !! '' }, @(self) }
    method P5scalar(Array:) { +@(self) }
}

augment class List {
    multi method P5Str(List:U:) { '' }
    multi method P5Str(List:D:) { join '', map { $_.defined ?? $_.P5Str !! '' }, @(self) }
    method P5scalar(List:) { +@(self) }
}

augment class Str {
    multi method P5Str(Str:D:) { self.Str    }
    multi method P5Numeric(Str:U) { 0 }
    multi method P5Numeric(Str:D:) {
        my str $str = nqp::unbox_s(self);
        my int $eos = nqp::chars($str);

        # S02:3276-3277: Ignore leading and trailing whitespace
        my int $pos = nqp::findnotcclass(nqp::const::CCLASS_WHITESPACE,
                                                  $str, 0, $eos);
        my int $end = nqp::sub_i($eos, 1);

        $end = nqp::sub_i($end, 1)
            while nqp::isge_i($end, $pos)
               && nqp::iscclass(nqp::const::CCLASS_WHITESPACE, $str, $end);

        # Return 0 if no non-whitespace characters in string
        return 0 if nqp::islt_i($end, $pos);

        # Reset end-of-string after trimming
        $eos = nqp::add_i($end, 1);

        # Fail all the way out when parse failures occur
        my &parse_fail := -> $msg {
            fail X::Str::Numeric.new(
                    source => self,
                    reason => $msg,
                    :$pos,
            );
        };

        my sub parse-simple-number () {
            # Handle NaN here, to make later parsing simpler
            if nqp::iseq_s(nqp::substr($str, $pos, 3), 'NaN') {
                $pos = nqp::add_i($pos, 3);
                return nqp::p6box_n(nqp::nan());
            }

            # Handle any leading +/- sign
            my int $ch  = nqp::ord($str, $pos);
            my int $neg = nqp::iseq_i($ch, 45);                # '-'
            if nqp::iseq_i($ch, 45) || nqp::iseq_i($ch, 43) {  # '-', '+'
                $pos = nqp::add_i($pos, 1);
                $ch  = nqp::islt_i($pos, $eos) && nqp::ord($str, $pos);
            }

            # nqp::radix_I parse results, and helper values
            my Mu  $parse;
            my str $prefix;
            my int $radix;
            my int $p;

            my sub parse-int-frac-exp () {
                # Integer part, if any
                my Int:D $int := 0;
                if nqp::isne_i($ch, 46) {  # '.'
                    $parse := nqp::radix_I($radix, $str, $pos, $neg, Int);
                    $p      = nqp::atpos($parse, 2);
                    #~ parse_fail "base-$radix number must begin with valid digits or '.'"
                    return 0
                        if nqp::iseq_i($p, -1);
                    $pos    = $p;

                    $int   := nqp::atpos($parse, 0);
                    $ch     = nqp::islt_i($pos, $eos) && nqp::ord($str, $pos);
                }

                # Fraction, if any
                my Int:D $frac := 0;
                my Int:D $base := 0;
                if nqp::iseq_i($ch, 46) {  # '.'
                    $pos    = nqp::add_i($pos, 1);
                    $parse := nqp::radix_I($radix, $str, $pos,
                                           nqp::add_i($neg, 4), Int);
                    $p      = nqp::atpos($parse, 2);
                    #~ parse_fail 'radix point must be followed by one or more valid digits'
                        #~ if nqp::iseq_i($p, -1);
                    $pos    = $p;

                    $frac  := nqp::atpos($parse, 0);
                    $base  := nqp::atpos($parse, 1);
                    $ch     = nqp::islt_i($pos, $eos) && nqp::ord($str, $pos);
                }

                # Exponent, if 'E' or 'e' are present (forces return type Num)
                if nqp::iseq_i($ch, 69) || nqp::iseq_i($ch, 101) {  # 'E', 'e'
                    parse_fail "'E' or 'e' style exponent only allowed on decimal (base-10) numbers, not base-$radix"
                        unless nqp::iseq_i($radix, 10);

                    $pos    = nqp::add_i($pos, 1);
                    $parse := nqp::radix_I(10, $str, $pos, 2, Int);
                    $p      = nqp::atpos($parse, 2);
                    parse_fail "'E' or 'e' must be followed by decimal (base-10) integer"
                        if nqp::iseq_i($p, -1);
                    $pos    = $p;

                    my num $exp  = nqp::atpos($parse, 0);
                    my num $coef = $frac ?? nqp::add_n($int, nqp::div_n($frac, $base)) !! $int;
                    return nqp::p6box_n(nqp::mul_n($coef, nqp::pow_n(10, $exp)));
                }

                # Multiplier with exponent, if single '*' is present
                # (but skip if current token is '**', as otherwise we
                # get recursive multiplier parsing stupidity)
                if nqp::iseq_i($ch, 42)
                && nqp::isne_s(substr($str, $pos, 2), '**') {  # '*'
                    $pos           = nqp::add_i($pos, 1);
                    my $mult_base := parse-simple-number();

                    parse_fail "'*' multiplier base must be an integer"
                        unless $mult_base.WHAT === Int;
                    parse_fail "'*' multiplier base must be followed by '**' and exponent"
                        unless nqp::iseq_s(nqp::substr($str, $pos, 2), '**');

                    $pos           = nqp::add_i($pos, 2);
                    my $mult_exp  := parse-simple-number();

                    parse_fail "'**' multiplier exponent must be an integer"
                        unless $mult_exp.WHAT === Int;

                    my $mult := $mult_base ** $mult_exp;
                    $int     := $int  * $mult;
                    $frac    := $frac * $mult;
                }

                # Return an Int if there was no radix point
                return $int unless $base;

                # Otherwise, return a Rat
                my Int:D $numerator := $int * $base + $frac;
                return Rat.new($numerator, $base);
            }

            # Look for radix specifiers
            if nqp::iseq_i($ch, 58) {  # ':'
                # A string of the form :16<FE_ED.F0_0D> or :60[12,34,56]
                $pos    = nqp::add_i($pos, 1);
                $parse := nqp::radix_I(10, $str, $pos, 0, Int);
                $p      = nqp::atpos($parse, 2);
                parse_fail "radix (in decimal) expected after ':'"
                    if nqp::iseq_i($p, -1);
                $pos    = $p;

                $radix  = nqp::atpos($parse, 0);
                $ch     = nqp::islt_i($pos, $eos) && nqp::ord($str, $pos);
                if    nqp::iseq_i($ch, 60) {  # '<'
                    $pos = nqp::add_i($pos, 1);

                    my $result := parse-int-frac-exp();

                    parse_fail "malformed ':$radix<>' style radix number, expecting '>' after the body"
                        unless nqp::islt_i($pos, $eos)
                            && nqp::iseq_i(nqp::ord($str, $pos), 62);  # '>'

                    $pos = nqp::add_i($pos, 1);
                    return $result;
                }
                elsif nqp::iseq_i($ch, 171) {  # '«'
                    $pos = nqp::add_i($pos, 1);

                    my $result := parse-int-frac-exp();

                    parse_fail "malformed ':$radix«»' style radix number, expecting '»' after the body"
                        unless nqp::islt_i($pos, $eos)
                            && nqp::iseq_i(nqp::ord($str, $pos), 187);  # '»'

                    $pos = nqp::add_i($pos, 1);
                    return $result;
                }
                elsif nqp::iseq_i($ch, 91) {  # '['
                    $pos = nqp::add_i($pos, 1);
                    my Int:D $result := 0;
                    my Int:D $digit  := 0;
                    while nqp::islt_i($pos, $eos)
                       && nqp::isne_i(nqp::ord($str, $pos), 93) {  # ']'
                        $parse := nqp::radix_I(10, $str, $pos, 0, Int);
                        $p      = nqp::atpos($parse, 2);
                        parse_fail "malformed ':$radix[]' style radix number, expecting comma separated decimal values after opening '['"
                            if nqp::iseq_i($p, -1);
                        $pos    = $p;

                        $digit := nqp::atpos($parse, 0);
                        parse_fail "digit is larger than {$radix - 1} in ':$radix[]' style radix number"
                            if $digit >= $radix;

                        $result := $result * $radix + $digit;
                        $pos     = nqp::add_i($pos, 1)
                            if nqp::islt_i($pos, $eos)
                            && nqp::iseq_i(nqp::ord($str, $pos), 44);  # ','
                    }
                    parse_fail "malformed ':$radix[]' style radix number, expecting ']' after the body"
                        unless nqp::islt_i($pos, $eos)
                            && nqp::iseq_i(nqp::ord($str, $pos), 93);  # ']'
                    $pos = nqp::add_i($pos, 1);

                    # XXXX: Handle fractions!
                    # XXXX: Handle exponents!
                    return $neg ?? -$result !! $result;
                }
                else {
                    parse_fail "malformed ':$radix' style radix number, expecting '<' or '[' after the base";
                }
            }
            elsif nqp::iseq_i($ch, 48)  # '0'
              and $radix = nqp::index('  b     o d     x',
                                      nqp::substr($str, nqp::add_i($pos, 1), 1))
              and nqp::isge_i($radix, 2) {
                # A string starting with 0x, 0d, 0o, or 0b,
                # followed by one optional '_'
                $pos   = nqp::add_i($pos, 2);
                $pos   = nqp::add_i($pos, 1)
                    if nqp::islt_i($pos, $eos)
                    && nqp::iseq_i(nqp::ord($str, $pos), 95);  # '_'

                return parse-int-frac-exp();
            }
            elsif nqp::iseq_s(nqp::substr($str, $pos, 3), 'Inf') {
                # 'Inf'
                $pos = nqp::add_i($pos, 3);
                return $neg ?? -$Inf !! $Inf;
            }
            else {
                # Last chance: a simple decimal number
                $radix = 10;
                return parse-int-frac-exp();
            }
        }

        my sub parse-real () {
            # Parse a simple number or a Rat numerator
            my $result := parse-simple-number();
            return $result if nqp::iseq_i($pos, $eos);

            # Check for '/' indicating Rat denominator
            if nqp::iseq_i(nqp::ord($str, $pos), 47) {  # '/'
                $pos = nqp::add_i($pos, 1);
                parse_fail "denominator expected after '/'"
                    unless nqp::islt_i($pos, $eos);

                my $denom := parse-simple-number();

                $result := $result.WHAT === Int && $denom.WHAT === Int
                        ?? Rat.new($result, $denom)
                        !! $result / $denom;
            }

            return $result;
        }

        # Parse a real number, magnitude of a pure imaginary number,
        # or real part of a complex number
        my $result := parse-real();
        return $result if nqp::iseq_i($pos, $eos);

        # Check for 'i' or '\\i' indicating first parsed number was
        # the magnitude of a pure imaginary number
        if nqp::iseq_i(nqp::ord($str, $pos), 105) {  # 'i'
            $pos = nqp::add_i($pos, 1);
            $result := Complex.new(0, $result);
        }
        elsif nqp::iseq_s(nqp::substr($str, $pos, 2), '\\i') {
            $pos = nqp::add_i($pos, 2);
            $result := Complex.new(0, $result);
        }
        # Check for '+' or '-' indicating first parsed number was
        # the real part of a complex number
        elsif nqp::iseq_i(nqp::ord($str, $pos), 45)    # '-'
           || nqp::iseq_i(nqp::ord($str, $pos), 43) {  # '+'
            # Don't move $pos -- we want parse-real() to see the sign
            my $im := parse-real();
            parse_fail "imaginary part of complex number must be followed by 'i' or '\\i'"
                unless nqp::islt_i($pos, $eos);

            if nqp::iseq_i(nqp::ord($str, $pos), 105) {  # 'i'
                $pos = nqp::add_i($pos, 1);
            }
            elsif nqp::iseq_s(nqp::substr($str, $pos, 2), '\\i') {
                $pos = nqp::add_i($pos, 2);
            }
            else {
                parse_fail "imaginary part of complex number must be followed by 'i' or '\\i'"
            }

            $result := Complex.new($result, $im);
        }

        # Check for trailing garbage
        #~ parse_fail "trailing characters after number"
            #~ if nqp::islt_i($pos, $eos);

        return $result;
    }
    method P5do(Str:)          { _P5do(self) }
    method P5scalar(Str:) { self.P5Str }
    method P5ord(Str:) { self ?? self.ord !! 0 }
}

augment class Int {
    multi method P5Str(Int:U:) { '' }
    multi method P5Str(Int:D:) { self.Int }
    method P5Numeric(Int:) { self }
    method P5scalar(Int:) { self.P5Str }
}

augment class Num {
    multi method P5Str(Num:U:) { '' }
    multi method P5Str(Num:D:) { self.Num }
    method P5Numeric(Num:) { self }
    method P5scalar(Num:) { self.P5Str }
}

augment class Capture {
    multi method P5Str(Capture:D:) { self.Str }
    method P5scalar(Capture:) { self.P5Str }
}

augment class Match {
    multi method P5Str(Match:D:) { self.Str }
}

augment class Rat {
    multi method P5Str(Rat:D:) { self.Str }
    method P5Numeric(Rat:) { self }
    method P5scalar(Rat:) { self.P5Str }
}

augment class Parcel {
    multi method P5Str(Parcel:D:) { self.Int }
    method P5scalar(Parcel:) { self.P5Str }
}

augment class Sub {
    multi method P5Str(Sub:D:) { 'CODE(' ~ self.WHERE.fmt('0x%X').lc ~ ')' }
    method P5scalar(Sub:) { self.P5Str }
}

# class A { method new { bless([], self)}; method a { 42 } }; my $a = A.new; say $a.a; $a[0] = 1; say $a.WHAT
#~ sub bless(*@a) is export {
    #~ my class Dummy { };
    #~ my $d := Dummy.HOW.new_type();
    #~ $d.HOW.add_parent( $d, $_ ) for @a;
    #~ $d.HOW.compose($d)
#~ };
