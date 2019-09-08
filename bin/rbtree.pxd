# cython: c_string_encoding="utf-8", binding=True, boundscheck=True, cdivision=True, embedsignature=True, initializedcheck=False, nonecheck=False, wraparound=True, optimize.unpack_method_calls=True, optimize.use_switch=True, warn.maybe_uninitialzed=True, warn.multiple_declarators=True, warn.undeclared=False, warn.unreacheable=True, warn.unused_arg=True, warn.unused_result=True, warn.unused=True
# -*- coding: utf-8 -*-

from __future__ import absolute_import, division, print_function

cimport cython

cdef class Node:
    cdef Py_ssize_t rb_parent_color
    cdef object rb_left
    cdef object rb_right

    cdef next_node(self)

    cdef previous_node(self)

    cdef remove_node(self)


@cython.final
cdef class Root:
    cdef object rb_node

    cdef object check(self)

    cdef object first_node(self)

    cdef object last_node(self)

    cdef object add_node(
        self,
        object rb_node)

