#!perl

## Perl version check ($^V).
use v5.35.0;
no v6.0.0;

## Modules (@INC).
use Getopt::Long 'GetOptions';
use Path::Tiny 'path';

## Settings.
my $VERSION = 'v0.0.0';


sub obfuscate($input, $output) {
    my $content = path($input)->slurp;

    sub remove_comments($content) {
        $content =~ s/<#.*?#>//gs; ## '<#...#>' -> ''
        $content =~ s/#.*\n//g;    ## '#...'    -> ''
        return $content;
    }

    sub remove_spacelikes($content) {
        ## Remove empty lines.
        $content =~ s/^\s*\n//gm; ## '^$' -> ''

        ## Remove leading and trailing space-like characters.
        $content =~ s/^\s*//gm; ## ' ...' -> '...'
        $content =~ s/\s*$//gm; ## '... ' -> '...'

        ## Replace new lines with semicolons.
        $content =~ s/\n/;/g; ## '\n' -> ';'

        ## Remove redundant space-like characters.
        $content =~ s/\s+/ /g; ## '  ' -> ' '

        ## Remove unnecessary semicolons.
        $content =~ s/{;/{/g; ## '{;' -> '{'
        $content =~ s/;}/}/g; ## ';}' -> '}'

        ## Remove unnecessary space-like characters.
        $content =~ s/\s=/=/g;   ## ' =' -> '='
        $content =~ s/=\s/=/g;   ## '= ' -> '='
        $content =~ s/\s\+/\+/g; ## ' +' -> '+'
        $content =~ s/\+\s/\+/g; ## '+ ' -> '+'
        $content =~ s/\s,/,/g;   ## ' ,' -> ','
        $content =~ s/,\s/,/g;   ## ', ' -> ','
        $content =~ s/\s\|/\|/g; ## ' |' -> '|'
        $content =~ s/\|\s/\|/g; ## '| ' -> '|'
        $content =~ s/\s\{/\{/g; ## ' {' -> '{'
        $content =~ s/\{\s/\{/g; ## '{ ' -> '{'
        $content =~ s/\s\}/\}/g; ## ' }' -> '}'
        $content =~ s/\}\s/\}/g; ## '} ' -> '}'
        $content =~ s/\s\(/\(/g; ## ' )' -> '('
        $content =~ s/\(\s/\(/g; ## '( ' -> '('
        $content =~ s/\s\)/\)/g; ## ' )' -> ')'
        $content =~ s/\)\s/\)/g; ## ') ' -> ')'
        return $content;
    }

    sub obfuscate_booleans($content) {
        sub generate_true_bool() {
            my $r1 = int(rand(1000000)) + 1;
            my $r2 = int(rand(1000000)) + 1;
            my $r3 = int(rand(1000000)) + 1;
            my @rc1 = ('+', '*');
            my @rc2 = ('+', '*');
            return "[bool]($r1$rc1[rand(@rc1)]($r2$rc2[rand(@rc2)]$r3))";
        }

        sub generate_false_bool() {
            my $r1 = int(rand(1000000)) + 1;
            my $r2 = int(rand(1000000)) + 1;
            my @rc = ('+', '-', '*', '/', '%' );
            return "[bool](($r1$rc[rand(@rc)]$r2)*0)";
        }

        $content =~ s/\$true/generate_true_bool()/egi;   ## '$True'  -> '[bool](1)'
        $content =~ s/\$false/generate_false_bool()/egi; ## '$False' -> '[bool](0)'
        return $content;
    }

    sub obfuscate_variables($content) {
        sub generate_variable_name($length) {
            my @chars = ('a' .. 'z', '0' .. '9');
            my $string = '';
            for (1 .. $length) {
                my $char = $chars[rand(@chars)];
                $string .= $char;
            }
            return '$' . $string;
        }

        ## Find all variables.
        my @vars = ();
        while ($content =~ /(\$[a-z0-9_]+)/gi) {
            push @vars, $1;
        }

        ## Preserve only unique variables.
        my %uniq_vars;
        @vars = grep { !$uniq_vars{$_}++ } @vars;

        ## Remove protected variables.
        my @protected_vars = ('$_', '$null', '$script');
        my %protected_vars_lookup = map { $_ => 1 } @protected_vars;
        @vars = grep { !$protected_vars_lookup { $_ } } @vars;

        ## Remove scope-modified variables.
        my @script_vars = ();
        while ($content =~ /(\$script:[a-z0-9_]+)/gi) {
            my $script_var = $1;
            $script_var =~ s/script://;
            push @script_vars, $script_var;
        }
        my %script_vars_lookup = map { $_ => 1 } @script_vars;
        @vars = grep { !$script_vars_lookup { $_ } } @vars;

        ## Replace all variables with unique random string.
        foreach my $var (@vars) {
            ## Make sure that generated variable is unique and not already used.
            while (1) {
                my $mangled_var = generate_variable_name(32);
                if (index($content, $mangled_var) == -1) {
                    $content =~ s/\Q$var/$mangled_var/eg;
                    last;
                }
            }
        }

        ## Also replace all scope-modified variables.
        foreach my $var (@script_vars) {
            $var =~ s/\$//;
            ## Make sure that generated variable is unique and not already used.
            while (1) {
                my $mangled_var = generate_variable_name(32);
                $mangled_var =~ s/\$//;
                if (index($content, $mangled_var) == -1) {
                    $content =~ s/\Q$var/$mangled_var/eg;
                    last;
                }
            }
        }
        return $content;
    }

    $content = remove_comments($content);
    $content = remove_spacelikes($content);
    $content = obfuscate_booleans($content);
    $content = obfuscate_variables($content);
    ############################################################################
    print($content);
}


sub help() {
    say('NAME');
    say('    psod - PowerShell Of Death');
    say('');
    say('SYNOPSIS');
    say('    psod [-h|-v]');
    say('    psod [-o FILE] -i FILE');
    say('');
    say('DESCRIPTION');
    say('    -h      = Help.');
    say('    -i FILE = Input file.');
    say('    -o FILE = Output file.');
    say('    -v      = Version.');
    say('');
    say('EXAMPLES');
    say('    Obfuscate PowerShell script and save the output as obfuscated.ps1:');
    say('        $ psod -o obfuscated.ps1 -i deobfuscated.ps1');
    say('');
    say('EXIT STATUS');
    say('    0 = success');
    say('    1 = error');
    exit(0);
}


sub version() {
    say("psod $VERSION");
    exit(0);
}


sub main() {
    ## Command line options.
    my $help = '';
    my $input = '';
    my $output = '';
    my $version = '';
    GetOptions(
        'h|help!' => \$help,
        'i|input=s' => \$input,
        'o|output=s' => \$output,
        'v|version!' => \$version,
    );

    ## Program control.
    if ($version && !$help) {
        version();
    } elsif ($help || !$input) {
        help();
    } else {
        obfuscate($input, $output);
    }
}

main();
