/* deadcode.l */
%{
#include "deadcode.tab.h"
#include <string.h>
%}

%%

"int"           { return INT; }
"return"        { return RETURN; }
"{"             { return LBRACE; }
"}"             { return RBRACE; }
"("             { return LPAREN; }
")"             { return RPAREN; }
","             { return COMMA; }
";"             { return SEMICOLON; }
"+"             { return PLUS; }
"-"             { return MINUS; }
"*"             { return MULT; }
"/"             { return DIV; }
"="             { return ASSIGN; }      /* NEW */

[0-9]+ {
    yylval.num = atoi(yytext);
    return NUMBER;
}

[a-zA-Z_][a-zA-Z0-9_]* {
    yylval.str = strdup(yytext);
    return IDENTIFIER;
}

[ \t\r\n]+      ;      /* skip whitespace */
.               { return yytext[0]; }

%%

int yywrap() { return 1; }
