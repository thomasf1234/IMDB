#include <ruby.h>

VALUE Core = Qnil;

void Init_core();
VALUE method_core_is_immediate(VALUE self, VALUE obj);

void Init_core() {
  Core = rb_define_module("Core");
  rb_define_singleton_method(Core, "is_immediate_value?", method_core_is_immediate, 1);
}

VALUE method_core_is_immediate(VALUE self, VALUE obj) {
  if (rb_special_const_p(obj)) return (int)RUBY_Qtrue;
    return (int)RUBY_Qfalse;
}


