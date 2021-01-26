/**
 * Test the C++ compiler interface of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2017-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     Iain Buclaw
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/tests/cxxfrontend.c, _cxxfrontend.c)
 */

#include "root/array.h"
#include "root/ctfloat.h"
#include "root/dcompat.h"
#include "root/file.h"
#include "root/filename.h"
#include "root/longdouble.h"
#include "root/object.h"
#include "root/outbuffer.h"
#include "root/port.h"
#include "root/rmem.h"
#include "root/root.h"

#include "aggregate.h"
#include "aliasthis.h"
#include "arraytypes.h"
#include "ast_node.h"
#include "attrib.h"
#include "compiler.h"
#include "complex_t.h"
#include "cond.h"
#include "ctfe.h"
#include "declaration.h"
#include "doc.h"
#include "dsymbol.h"
#include "enum.h"
#include "errors.h"
#include "expression.h"
#include "globals.h"
#include "hdrgen.h"
#include "identifier.h"
#include "id.h"
#include "import.h"
#include "init.h"
#include "json.h"
#include "mangle.h"
#include "module.h"
#include "mtype.h"
#include "nspace.h"
#include "objc.h"
#include "scope.h"
#include "statement.h"
#include "staticassert.h"
#include "target.h"
#include "template.h"
#include "tokens.h"
#include "version.h"
#include "visitor.h"

/**********************************/

extern "C" int rt_init();
extern "C" void gc_disable();

static void frontend_init()
{
    rt_init();
    gc_disable();

    global._init();
    global.params.isLinux = true;
    global.vendor = DString("Front-End Tester");

    Type::_init();
    Id::initialize();
    Module::_init();
    Expression::_init();
    Objc::_init();
    target._init(global.params);
    CTFloat::initialize();
}

/**********************************/

extern "C" int rt_term();
extern "C" void gc_enable();

static void frontend_term()
{
  gc_enable();
  rt_term();
}

/**********************************/

class TestVisitor : public Visitor
{
  public:
    bool expr;
    bool package;
    bool stmt;
    bool type;
    bool aggr;
    bool attrib;
    bool decl;
    bool typeinfo;
    bool idexpr;

    TestVisitor() : expr(false), package(false), stmt(false), type(false),
        aggr(false), attrib(false), decl(false), typeinfo(false), idexpr(false)
    {
    }

    void visit(Expression *)
    {
        expr = true;
    }

    void visit(IdentifierExp *)
    {
        idexpr = true;
    }

    void visit(Package *)
    {
        package = true;
    }

    void visit(Statement *)
    {
        stmt = true;
    }

    void visit(AttribDeclaration *)
    {
        attrib = true;
    }

    void visit(Declaration *)
    {
        decl = true;
    }

    void visit(AggregateDeclaration *)
    {
        aggr = true;
    }

    void visit(TypeNext *)
    {
        type = true;
    }

    void visit(TypeInfoDeclaration *)
    {
        typeinfo = true;
    }
};

void test_visitors()
{
    TestVisitor tv;
    Loc loc;
    Identifier *ident = Identifier::idPool("test");

    IntegerExp *ie = IntegerExp::create(loc, 42, Type::tint32);
    ie->accept(&tv);
    assert(tv.expr == true);

    IdentifierExp *id = IdentifierExp::create (loc, ident);
    id->accept(&tv);
    assert(tv.idexpr == true);

    Module *mod = Module::create("test", ident, 0, 0);
    assert(mod->isModule() == mod);
    mod->accept(&tv);
    assert(tv.package == true);

    ExpStatement *es = ExpStatement::create(loc, ie);
    assert(es->isExpStatement() == es);
    es->accept(&tv);
    assert(tv.stmt == true);

    TypePointer *tp = TypePointer::create(Type::tvoid);
    assert(tp->hasPointers() == true);
    tp->accept(&tv);
    assert(tv.type == true);

    LinkDeclaration *ld = LinkDeclaration::create(LINKd, NULL);
    assert(ld->isAttribDeclaration() == static_cast<AttribDeclaration *>(ld));
    assert(ld->linkage == LINKd);
    ld->accept(&tv);
    assert(tv.attrib == true);

    ClassDeclaration *cd = ClassDeclaration::create(loc, Identifier::idPool("TypeInfo"), NULL, NULL, true);
    assert(cd->isClassDeclaration() == cd);
    assert(cd->vtblOffset() == 1);
    cd->accept(&tv);
    assert(tv.aggr == true);

    AliasDeclaration *ad = AliasDeclaration::create(loc, ident, tp);
    assert(ad->isAliasDeclaration() == ad);
    ad->storage_class = STCabstract;
    assert(ad->isAbstract() == true);
    ad->accept(&tv);
    assert(tv.decl == true);

    cd = ClassDeclaration::create(loc, Identifier::idPool("TypeInfo_Pointer"), NULL, NULL, true);
    TypeInfoPointerDeclaration *ti = TypeInfoPointerDeclaration::create(tp);
    assert(ti->isTypeInfoDeclaration() == ti);
    assert(ti->tinfo == tp);
    ti->accept(&tv);
    assert(tv.typeinfo == true);
}

/**********************************/

void test_semantic()
{
    /* Mini object.d source. Module::parse will add internal members also. */
    const char *buf =
        "module object;\n"
        "class Object { }\n"
        "class Throwable { }\n"
        "class Error : Throwable { this(immutable(char)[]); }";

    FileBuffer *srcBuffer = FileBuffer::create(); // free'd in Module::parse()
    srcBuffer->data = DArray<unsigned char>(strlen(buf), (unsigned char *)mem.xstrdup(buf));

    Module *m = Module::create("object.d", Identifier::idPool("object"), 0, 0);

    unsigned errors = global.startGagging();

    m->srcBuffer = srcBuffer;
    m->parse();
    m->importedFrom = m;
    m->importAll(NULL);
    dsymbolSemantic(m, NULL);
    semantic2(m, NULL);
    semantic3(m, NULL);

    Dsymbol *s = m->search(Loc(), Identifier::idPool("Error"));
    assert(s);
    AggregateDeclaration *ad = s->isAggregateDeclaration();
    assert(ad && ad->ctor);
    CtorDeclaration *ctor = ad->ctor->isCtorDeclaration();
    assert(ctor->isMember() && !ctor->isNested());
    assert(0 == strcmp(ctor->type->toChars(), "Error(string)"));

    ClassDeclaration *cd = ad->isClassDeclaration();
    assert(cd && cd->hasMonitor());

    assert(!global.endGagging(errors));
}

/**********************************/

void test_expression()
{
    Loc loc;
    IntegerExp *ie = IntegerExp::create(loc, 42, Type::tint32);
    Expression *e = ie->ctfeInterpret();

    assert(e);
    assert(e->isConst());
}

/**********************************/

void test_target()
{
    assert(target.isVectorOpSupported(Type::tint32, TOKpow));
}

/**********************************/

void test_emplace()
{
    Loc loc;
    UnionExp ue;

    IntegerExp::emplace(&ue, loc, 1065353216, Type::tint32);
    Expression *e = ue.exp();
    assert(e->op == TOKint64);
    assert(e->toInteger() == 1065353216);

    UnionExp ure;
    Expression *re = Compiler::paintAsType(&ure, e, Type::tfloat32);
    assert(re->op == TOKfloat64);
    assert(re->toReal() == CTFloat::one);

    UnionExp uie;
    Expression *ie = Compiler::paintAsType(&uie, re, Type::tint32);
    assert(ie->op == TOKint64);
    assert(ie->toInteger() == e->toInteger());
}

/**********************************/

void test_parameters()
{
    Parameters *args = new Parameters;
    args->push(Parameter::create(STCundefined, Type::tint32, NULL, NULL, NULL));
    args->push(Parameter::create(STCundefined, Type::tint64, NULL, NULL, NULL));

    TypeFunction *tf = TypeFunction::create(args, Type::tvoid, VARARGnone, LINKc);

    assert(tf->parameterList.length() == 2);
    assert(tf->parameterList[0]->type == Type::tint32);
    assert(tf->parameterList[1]->type == Type::tint64);
}

/**********************************/

void test_location()
{
    Loc loc1 = Loc("test.d", 24, 42);
    assert(loc1.equals(Loc("test.d", 24, 42)));
    assert(strcmp(loc1.toChars(true), "test.d(24,42)") == 0);
}

/**********************************/

int main(int argc, char **argv)
{
    frontend_init();

    test_visitors();
    test_semantic();
    test_expression();
    test_target();
    test_emplace();
    test_parameters();
    test_location();

    frontend_term();

    return 0;
}
