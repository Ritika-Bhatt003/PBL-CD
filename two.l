%{
#include "two.tab.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

extern FILE *outfile;
%}

%%

\/\/[^\n]* {
    yylval.str = strdup(yytext);
    return COMMENT;
}

\/\*([^*]|\*+[^*/])*\*+\/ {
    yylval.str = strdup(yytext);
    return COMMENT;
}

"int"           { return INT; }
"return"        { return RETURN; }
"if"            { return IF; }
"else"          { return ELSE; }
"while"         { return WHILE; }
"break"         { return BREAK; }

"("             { return LPAREN; }
")"             { return RPAREN; }
"{"             { return LBRACE; }
"}"             { return RBRACE; }
";"             { return SEMICOLON; }
"="             { return ASSIGN; }

[0-9]+          { yylval.str = strdup(yytext); return NUMBER; }

[a-zA-Z_][a-zA-Z0-9_]* {
                    yylval.str = strdup(yytext);
                    return IDENTIFIER;
                }

[ \t\r\n]+      ;  // skip whitespace

.               { return yytext[0]; }

%%
