/* deadcode.y */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void yyerror(const char *s);
int  yylex(void);

/* ---------- bookkeeping ---------- */
int found_return = 0;

/* locals */
int   variable_used[100] = {0};
char* variable_names[100];
int   var_count = 0;

/* parameters */
char* param_names[100];
int   param_count = 0;

/* calls & decls */
char* called_funcs[100];
int   called_count = 0;
char* func_names[100];
int   func_decl_count = 0;

/* output buffers */
FILE *outfile;
char  stmt_buffer[10000];

typedef struct { char *name; char *text; } FuncBuf;
FuncBuf funcs[100];
int     func_buf_cnt = 0;

/* ---------- helpers ---------- */
void reset_vars(void)
{
    for (int i = 0; i < var_count; i++)   free(variable_names[i]);
    for (int i = 0; i < param_count; i++) free(param_names[i]);
    var_count = param_count = 0;
    memset(variable_used, 0, sizeof(variable_used));
    stmt_buffer[0] = '\0';
}
int is_var_used(const char *s)
{
    for (int i = 0; i < var_count; i++)
        if (!strcmp(variable_names[i], s)) { variable_used[i]=1; return 1; }
    return 0;
}
int already_called(const char *s)
{
    for (int i = 0; i < called_count; i++)
        if (!strcmp(called_funcs[i], s)) return 1;
    return 0;
}
void track_call(const char *s)
{
    if (!already_called(s)) called_funcs[called_count++] = strdup(s);
}
%}

%union { char* str; int num; }

%token <str> IDENTIFIER
%token <num> NUMBER
%token INT RETURN LBRACE RBRACE LPAREN RPAREN SEMICOLON COMMA
%token PLUS MINUS MULT DIV ASSIGN

%left  PLUS MINUS
%left  MULT DIV
%right ASSIGN

%type <str> expression args

%% /* ---------- grammar ---------- */

program   : functions ;
functions :
      function functions
    | /* empty */
    ;
function  :
    INT IDENTIFIER LPAREN params RPAREN LBRACE stmts RBRACE
    {
        /* ---- build pretty body ---- */
        size_t cap = strlen(stmt_buffer)+4096;
        char *pretty = malloc(cap);

        snprintf(pretty,cap,"int %s(", $2);
        for(int i=0;i<param_count;i++){
            if(i) strcat(pretty,", ");
            strcat(pretty,"int "); strcat(pretty,param_names[i]);
        }
        strcat(pretty,") {\n");

        for(int i=0;i<var_count;i++){
            if(variable_used[i]){
                strcat(pretty,"    int "); strcat(pretty,variable_names[i]);
                strcat(pretty,";\n");
            }else printf("🔴 Dead variable: %s\n",variable_names[i]);
        }
        for(int i=0;i<param_count;i++)
            if(!strstr(stmt_buffer,param_names[i]))
                printf("🔴 Dead parameter: %s\n",param_names[i]);

        strcat(pretty,stmt_buffer); strcat(pretty,"}\n\n");

        funcs[func_buf_cnt].name=strdup($2);
        funcs[func_buf_cnt].text=pretty; func_buf_cnt++;

        free($2); reset_vars(); found_return=0;
    }
    ;
params    :
      /* empty */
    | param
    | param COMMA params
    ;
param     : INT IDENTIFIER { param_names[param_count++]=$2; };
stmts     :
      /* empty */
    | stmt stmts
    ;
stmt      :
      RETURN expression SEMICOLON
        {
            found_return=1;
            strcat(stmt_buffer,"    return "); strcat(stmt_buffer,$2);
            strcat(stmt_buffer,";\n"); free($2);
        }
    | expression SEMICOLON                /* <-- MODIFIED */
        {
            /* identifier-only? */
            int id_only = strspn($1,
              "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789")
              == strlen($1);

            if(id_only){
                is_var_used($1);   /* mark live, but **do NOT emit** */
            }else{
                printf("🔴 Dead expression: %s\n",$1);
            }
            free($1);
        }
    | IDENTIFIER LPAREN args RPAREN SEMICOLON
        {
            if(found_return)
                printf("⚠️ Unreachable code: function call after return\n");
            else{
                track_call($1);
                strcat(stmt_buffer,"    "); strcat(stmt_buffer,$1);
                strcat(stmt_buffer,"(");  strcat(stmt_buffer,$3);
                strcat(stmt_buffer,");\n");
            }
            free($1); free($3);
        }
    | INT IDENTIFIER SEMICOLON
        { variable_names[var_count]=$2; variable_used[var_count++]=0; }
    | IDENTIFIER ASSIGN expression SEMICOLON
        {
            is_var_used($1);
            strcat(stmt_buffer,"    "); strcat(stmt_buffer,$1);
            strcat(stmt_buffer," = ");  strcat(stmt_buffer,$3);
            strcat(stmt_buffer,";\n");
            free($1); free($3);
        }
    ;
args      :
      /* empty */           { $$=strdup(""); }
    | expression            { $$=$1; }
    | expression COMMA args {
            char buf[2048]; snprintf(buf,sizeof(buf),"%s, %s",$1,$3);
            free($1); free($3); $$=strdup(buf);
        }
    ;
expression:
      IDENTIFIER            { is_var_used($1); $$=$1; }
    | NUMBER                { char buf[64]; snprintf(buf,sizeof(buf),"%d",$1);
                               $$=strdup(buf); }
    | expression PLUS  expression { char buf[2048];
          snprintf(buf,sizeof(buf),"%s + %s",$1,$3); free($1);free($3); $$=strdup(buf);}
    | expression MINUS expression { char buf[2048];
          snprintf(buf,sizeof(buf),"%s - %s",$1,$3); free($1);free($3); $$=strdup(buf);}
    | expression MULT  expression { char buf[2048];
          snprintf(buf,sizeof(buf),"%s * %s",$1,$3); free($1);free($3); $$=strdup(buf);}
    | expression DIV   expression { char buf[2048];
          snprintf(buf,sizeof(buf),"%s / %s",$1,$3); free($1);free($3); $$=strdup(buf);}
    | LPAREN expression RPAREN    { char buf[2048];
          snprintf(buf,sizeof(buf),"(%s)",$2); free($2); $$=strdup(buf);}
    ;
%% /* ---------- code section ---------- */

void yyerror(const char *s){ fprintf(stderr,"Syntax Error: %s\n",s); }

int main(void)
{
    outfile=fopen("output.c","w");
    if(!outfile){ perror("fopen"); return 1; }

    yyparse();                        /* parse once */

    /* post-pass: emit only live funcs */
    for(int i=0;i<func_buf_cnt;i++){
        int live = !strcmp(funcs[i].name,"main") || already_called(funcs[i].name);
        if(!live){
            printf("🔴 Dead function: %s\n",funcs[i].name);
            continue;
        }
        fputs(funcs[i].text,outfile);
    }
    fclose(outfile);
    return 0;
}
