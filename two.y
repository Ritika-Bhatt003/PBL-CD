%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int  yylex(void);
void yyerror(const char *s);

FILE *outfile;

/* handy concat helper */
static char *concat(const char *a, const char *b) {
    char *res = malloc(strlen(a) + strlen(b) + 1);
    strcpy(res, a);
    strcat(res, b);
    return res;
}
%}

/* ---------- value types ---------- */
%union {
    char *str;
    struct {
        char *text;
        int   term;
    } node;
}

/* ---------- tokens ---------- */
%token <str> IDENTIFIER NUMBER COMMENT
%token INT RETURN IF ELSE WHILE BREAK
%token LBRACE RBRACE LPAREN RPAREN SEMICOLON ASSIGN

/* ---------- non-terminal value types ---------- */
%type <str>  program functions function
%type <str>  stmt_block
%type <node> stmt
%type <str>  expression

%%

program
    : functions               { fprintf(outfile,"%s",$1); free($1); }
    ;

functions
    : function                { $$ = $1; }
    | function functions      {
            $$ = concat($1, $2);
            free($1); free($2);
        }
    ;

function
    : INT IDENTIFIER LPAREN RPAREN LBRACE stmt_block RBRACE
        {
            char *hdr = concat("int ", $2);
            char *sig = concat(hdr, "() {\n");
            free(hdr);
            char *body = concat(sig, $6);
            free(sig); free($6);
            char *full = concat(body, "}\n\n");
            free(body);
            $$ = full;
            free($2);
        }
    ;

/* ---------------- TRIMMING UNREACHABLE CODE ---------------- */

stmt_block
    : /* empty */            { $$ = strdup(""); }
    | stmt stmt_block        {
            if ($1.term) {
                $$ = concat($1.text, "");
                free($1.text); free($2);
            } else {
                $$ = concat($1.text, $2);
                free($1.text); free($2);
            }
        }
    | COMMENT stmt_block     {
            char *tmp = malloc(strlen($1) + 8);
            sprintf(tmp, "    %s\n", $1);
            $$ = concat(tmp, $2);
            free(tmp); free($1); free($2);
        }
    ;

stmt
    : INT IDENTIFIER SEMICOLON
        {
            char buf[256];
            snprintf(buf,sizeof(buf), "    int %s;\n", $2);
            $$.text = strdup(buf); $$.term = 0;
            free($2);
        }
    | IDENTIFIER ASSIGN expression SEMICOLON
        {
            char buf[256];
            snprintf(buf,sizeof(buf), "    %s = %s;\n", $1, $3);
            $$.text = strdup(buf); $$.term = 0;
            free($1); free($3);
        }
    | IDENTIFIER ASSIGN IDENTIFIER LPAREN RPAREN SEMICOLON
        {
            char buf[256];
            snprintf(buf,sizeof(buf), "    %s = %s();\n", $1, $3);
            $$.text = strdup(buf); $$.term = 0;
            free($1); free($3);
        }
    | IDENTIFIER LPAREN RPAREN SEMICOLON
        {
            char buf[256];
            snprintf(buf,sizeof(buf), "    %s();\n", $1);
            $$.text = strdup(buf); $$.term = 0;
            free($1);
        }
    | BREAK SEMICOLON
        { $$.text = strdup("    break;\n"); $$.term = 1; }
    | RETURN expression SEMICOLON
        {
            char buf[256];
            snprintf(buf,sizeof(buf), "    return %s;\n", $2);
            $$.text = strdup(buf); $$.term = 1;
            free($2);
        }
    | IF LPAREN expression RPAREN LBRACE stmt_block RBRACE
        {
            if (!strcmp($3,"0")) {
                printf("dead if: if(0) block removed\n");
                $$.text = strdup(""); $$.term = 0;
            } else {
                char *tmp = malloc(strlen($3)+strlen($6)+32);
                sprintf(tmp,"    if (%s) {\n%s    }\n",$3,$6);
                $$.text = tmp; $$.term = 0;
            }
            free($3); free($6);
        }
    | IF LPAREN expression RPAREN LBRACE stmt_block RBRACE ELSE LBRACE stmt_block RBRACE
        {
            if (!strcmp($3,"0")) {
                printf("dead if: if(0) block removed\n");
                $$.text = strdup($10); $$.term = 0;
            } else if (!strcmp($3,"1")) {
                printf("dead else: else block removed due to if(1)\n");
                $$.text = strdup($6);  $$.term = 0;
            } else {
                char *tmp = malloc(strlen($3)+strlen($6)+strlen($10)+64);
                sprintf(tmp,"    if (%s) {\n%s    } else {\n%s    }\n",$3,$6,$10);
                $$.text = tmp; $$.term = 0;
            }
            free($3); free($6); free($10);
        }
    | WHILE LPAREN expression RPAREN LBRACE stmt_block RBRACE
        {
            if (!strcmp($3,"0")) {
                printf("dead while: while(0) loop removed\n");
                $$.text = strdup(""); $$.term = 0;
            } else {
                char *tmp = malloc(strlen($3)+strlen($6)+32);
                sprintf(tmp,"    while (%s) {\n%s    }\n",$3,$6);
                $$.text = tmp; $$.term = 0;
            }
            free($3); free($6);
        }
    ;

expression
    : IDENTIFIER           { $$ = strdup($1); free($1); }
    | NUMBER               { $$ = strdup($1); free($1); }
    ;

%%

void yyerror(const char *s) { fprintf(stderr,"Syntax Error: %s\n",s); }

int main(void)
{
    outfile = fopen("output.c","w");
    if (!outfile) { perror("output.c"); return 1; }

    if (yyparse()==0)
        fprintf(stderr,"Parsing and dead-code removal successful\n");
    else
        fprintf(stderr,"Parsing failed\n");

    fclose(outfile);
    return 0;
}
