use Perl6::Grammar;
use Perl5::Grammar;
use Perl5::ModuleLoader;

sub EXPORT(*@a) {
    Perl5::Grammar.HOW.trace-on(Perl5::Grammar)           if nqp::getenvhash()<V5TRACE> eq 'Perl5::Grammar';
    Perl5::QGrammar.HOW.trace-on(Perl5::QGrammar)         if nqp::getenvhash()<V5TRACE> eq 'Perl5::QGrammar';
    Perl5::RegexGrammar.HOW.trace-on(Perl5::RegexGrammar) if nqp::getenvhash()<V5TRACE> eq 'Perl5::RegexGrammar';
    
    %*LANG<Perl5>           := Perl5::Grammar;
    %*LANG<Perl5-actions>   := Perl5::Actions;
    %*LANG<P5Q>             := Perl5::QGrammar;
    %*LANG<P5Q-actions>     := Perl5::QActions;
    %*LANG<P5Regex>         := Perl5::RegexGrammar;
    %*LANG<P5Regex-actions> := Perl5::RegexActions;
    $*ACTIONS := %*LANG<Perl5-actions>;
    
    $*MAIN := 'Perl5';
    
    $*W.install_lexical_symbol($*W.cur_lexpad(), '%?LANG', $*W.p6ize_recursive(%*LANG));
    $*W.install_lexical_symbol($*W.cur_lexpad(), '$*MAIN', $*W.p6ize_recursive($*MAIN));

    my $PROCESS := nqp::gethllsym('perl6', 'PROCESS');
    if !nqp::isnull($PROCESS) && nqp::existskey($PROCESS.WHO, '%CUSTOM_LIB') {
        my $INC := ($PROCESS.WHO)<%CUSTOM_LIB>;
        if nqp::defined($INC) {
            my %INC := $INC.FLATTENABLE_HASH();
            unless nqp::existskey(%INC, 'Perl5') {
                %INC<Perl5> := $*W.find_symbol(['Array']).new;
                %INC<Perl5>.unshift: $*W.p6ize_recursive( %INC<perl> ~ '/lib/Perl5');
                my $PERL5LIB := nqp::atkey(nqp::getenvhash(), 'PERL5LIB');
                if nqp::defined($PERL5LIB) {
                    %INC<Perl5>.unshift: $*W.p6ize_recursive( nqp::split(':', $PERL5LIB) )
                }
                my $I := %*COMPILING<%?OPTIONS><I>;
                if nqp::defined($I) {
                    if nqp::islist($I) {
                        my $iter := nqp::iterator($I);
                        %INC<Perl5>.unshift: $*W.p6ize_recursive( nqp::shift($iter) ) while $iter;
                    }
                    else {
                        %INC<Perl5>.unshift: $*W.p6ize_recursive( $I );
                    }
                }
            }
        }
    }
    $*W.p6ize_recursive( nqp::hash() )
}
