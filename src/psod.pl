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

    $content = remove_comments($content);
    $content = remove_spacelikes($content);

    ############################################################################
    print($content);
}


sub deobfuscate($input, $output) {
    say('deobfuscating...');
}


sub help() {
    say('NAME');
    say('    psod - PowerShell Obfuscator and Deobfuscator');
    say('');
    say('SYNOPSIS');
    say('    psod [-d] [-o FILE] -i FILE');
    say('');
    say('DESCRIPTION');
    say('    -d      = Deobfuscate data.');
    say('    -h      = Show this help message and exit.');
    say('    -i FILE = Set input file to read data from.');
    say('    -o FILE = Put output to file instead of STDOUT.');
    say('    -v      = Print application version and exit.');
    say('');
    say('EXAMPLES');
    say('    Obfuscate PowerShell script and save the output as obfuscated.ps1:');
    say('        $ psod -o obfuscated.ps1 -i deobfuscated.ps1');
    say('    Deobfuscate PowerShell script and save the output as deobfuscated.ps1:');
    say('        $ psod -d -o deobfuscated.ps1 -i obfuscated.ps1');
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
    my $deobfuscate = '';
    my $help = '';
    my $input = '';
    my $output = '';
    my $version = '';
    GetOptions(
        'd|deobfuscate!' => \$deobfuscate,
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
    } elsif ($deobfuscate) {
        deobfuscate($input, $output);
    } else {
        obfuscate($input, $output);
    }
}

main();
