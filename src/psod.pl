#!perl

## Perl version check ($^V).
use v5.35.0;
no v6.0.0;

## Modules (@INC).
use Getopt::Long ('GetOptions');
use Path::Tiny ('path');
use MIME::Base64 ('encode_base64');
use Compress::Zlib ('compress');

## Settings.
my $VERSION = 'v0.0.0';


sub obfuscate($input, $output) {
    ## Read input file.
    my $content = path($input)->slurp;

    sub remove_comments_and_spacelikes($content) {
        ## Remove leading and trailing space-like characters.
        $content =~ s/^\s*//gm; ## ' ...' -> '...'
        $content =~ s/\s*$//gm; ## '... ' -> '...'

        ## Replace new lines with semicolons.
        $content =~ s/\n/;/g; ## '\n' -> ';'

        ## Remove multi-line and single-line comments.
        $content =~ s/<#.*?#>;//g; ## '<#...#>;' -> ''
        $content =~ s/#.*?;//g;    ## '#...;'    -> ''

        ## Remove unnecessary semicolons.
        $content =~ s/{;/{/g; ## '{;' -> '{'
        $content =~ s/;}/}/g; ## ';}' -> '}'

        ## Remove redundant space-like characters.
        $content =~ s/\s+/ /g; ## '  ' -> ' '

        ## Remove unnecessary space-like characters.
        $content =~ s/\s=/=/g;     ## ' ='  -> '='
        $content =~ s/=\s/=/g;     ## '= '  -> '='
        $content =~ s/\s\-\s/\-/g; ## ' - ' -> '-'
        $content =~ s/\s\+/\+/g;   ## ' +'  -> '+'
        $content =~ s/\+\s/\+/g;   ## '+ '  -> '+'
        $content =~ s/\s\*/\*/g;   ## ' *'  -> '*'
        $content =~ s/\*\s/\*/g;   ## '* '  -> '*'
        $content =~ s/\s\//\//g;   ## ' /'  -> '/'
        $content =~ s/\/\s/\//g;   ## '/ '  -> '/'
        $content =~ s/\s\%/\%/g;   ## ' %'  -> '%'
        $content =~ s/\%\s/\%/g;   ## '% '  -> '%'
        $content =~ s/\s,/,/g;     ## ' ,'  -> ','
        $content =~ s/,\s/,/g;     ## ', '  -> ','
        $content =~ s/\s\|/\|/g;   ## ' |'  -> '|'
        $content =~ s/\|\s/\|/g;   ## '| '  -> '|'
        $content =~ s/\s\{/\{/g;   ## ' {'  -> '{'
        $content =~ s/\{\s/\{/g;   ## '{ '  -> '{'
        $content =~ s/\s\}/\}/g;   ## ' }'  -> '}'
        $content =~ s/\}\s/\}/g;   ## '} '  -> '}'
        $content =~ s/\s\(/\(/g;   ## ' )'  -> '('
        $content =~ s/\(\s/\(/g;   ## '( '  -> '('
        $content =~ s/\s\)/\)/g;   ## ' )'  -> ')'
        $content =~ s/\)\s/\)/g;   ## ') '  -> ')'
        return $content;
    }

    sub obfuscate_variables($content) {
        sub booleans($content) {
            sub generate_true_bool() {
                my $r1 = int(rand(1000000)) + 1;
                my $r2 = int(rand(1000000)) + 1;
                my $r3 = int(rand(1000000)) + 1;
                my @rc1 = ('+', '*', '/');
                my @rc2 = ('+', '*', '/');
                return "[bool]($r1$rc1[rand(@rc1)]($r2$rc2[rand(@rc2)]$r3))";
            }

            sub generate_false_bool() {
                my $r1 = int(rand(1000000)) + 1;
                my $r2 = int(rand(1000000)) + 1;
                my @rc = ('+', '-', '*', '/', '%' );
                return "[bool](($r1$rc[rand(@rc)]$r2)*0)";
            }

            ## Replace '$True' and '$False' booleans with mathematical equations.
            $content =~ s/\$true/generate_true_bool()/egi;   ## '$True'  -> '[bool](1)'
            $content =~ s/\$false/generate_false_bool()/egi; ## '$False' -> '[bool](0)'
            return $content;
        }

        sub variables($content) {
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
            my @protected_vars = ('$_', '$null', '$env', '$script');
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

        sub functions($content) {
            sub generate_function_name($length) {
                my @chars = ('a' .. 'z', '0' .. '9');
                my $string = '';
                for (1 .. $length) {
                    my $char = $chars[rand(@chars)];
                    $string .= $char;
                }
                return $string;
            }

            ## Find all functions.
            my @functions = ();
            while ($content =~ /(function.*?\()/gi) {
                my $function = $1;
                $function =~ s/function\s//;
                $function =~ s/\(.*//;
                push @functions, $function;
            }

            ## Replace all functions with unique random string.
            foreach my $function (@functions) {
                while (1) {
                    my $mangled_function = generate_function_name(32);
                    if (index($content, $mangled_function) == -1) {
                        $content =~ s/\Q$function/$mangled_function/eg;
                        last;
                    }
                }
            }
            return $content;
        }

        $content = booleans($content);
        $content = variables($content);
        $content = functions($content);
        return $content;
    }

    sub randomize_case($content) {
        my $randomized_content = '';
        for my $c (split //, $content) {
            my $random = int(rand(2)) + 1;
            if ($random % 2 == 0) {
                if ($c =~ /[A-Z]/) {
                    $randomized_content .= lc($c);
                } elsif ($c =~ /[a-z]/) {
                    $randomized_content .= uc($c);
                } else {
                    $randomized_content .= "$c";
                }
            } else {
                $randomized_content .= "$c";
            }
        }
        return $randomized_content;
    }

    sub encode($content) {
        ## UTF-16LE encoding.
        my $encoded_content = '';
        for my $c (split //, $content) {
            $encoded_content .= $c . "\0";
        }

        ## Base64 encoding.
        $encoded_content = encode_base64($encoded_content);
        $encoded_content =~ s/\s//g;
        return $encoded_content;
    }

    ## Obfuscate with different methods.
    $content = remove_comments_and_spacelikes($content);
    $content = obfuscate_variables($content);
    $content = randomize_case($content);
    $content = encode($content);

    ## Write output to file or STDOUT.
    if (length($output) > 0) {
        $content .= "\n";
        path($output)->spew($content);
    } else {
        say($content);
    }
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

    ## Program logic.
    if ($version && !$help) {
        version();
    } elsif ($help || !$input) {
        help();
    } else {
        obfuscate($input, $output);
    }
}

main();
