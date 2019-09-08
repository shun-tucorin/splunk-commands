# cython: c_string_encoding="utf-8", binding=True, boundscheck=True, cdivision=True, embedsignature=True, initializedcheck=False, nonecheck=False, wraparound=True, optimize.unpack_method_calls=True, optimize.use_switch=True, warn.maybe_uninitialzed=True, warn.multiple_declarators=True, warn.undeclared=False, warn.unreacheable=True, warn.unused_arg=True, warn.unused_result=True, warn.unused=True
# -*- coding: utf-8 -*-

from __future__ import absolute_import, division, print_function

cimport cython

from cpython.object \
    cimport PyObject, \
            PyObject_Hash, \
            PyObject_RichCompare
from cpython.set \
    cimport PySet_Add, \
            PySet_Contains

cdef enum:
    RB_COLOR_MASK  = 0x1


@cython.inline
cdef bint rb_color_is_red(
        object rb_node):
    return ((<Node>(rb_node)).rb_parent_color & RB_COLOR_MASK) == 0


@cython.inline
cdef bint rb_color_is_black(
        object rb_node):
    return ((<Node>(rb_node)).rb_parent_color & RB_COLOR_MASK) != 0


@cython.inline
cdef object rb_color_set_red(
        object rb_node):
    (<Node>(rb_node)).rb_parent_color &= ~RB_COLOR_MASK


@cython.inline
cdef object rb_color_set_black(
        object rb_node):
    (<Node>(rb_node)).rb_parent_color |= RB_COLOR_MASK


@cython.inline
cdef object rb_get_parent(
        object rb_node):
    return <object>(<PyObject *>(<Py_ssize_t>((<Node>(rb_node)).rb_parent_color & ~RB_COLOR_MASK)))


@cython.inline
cdef object rb_set_parent(
        object rb_node,
        object rb_node_parent):
    (<Node>(rb_node)).rb_parent_color \
        = ((<Py_ssize_t>(<PyObject *>(rb_node_parent))) & ~RB_COLOR_MASK) \
            | (((<Node>(rb_node)).rb_parent_color) & RB_COLOR_MASK)


cdef object rb_color_try_set_black(
        object rb_node):
    if isinstance(rb_get_parent(rb_node), Node):
        if rb_color_is_black(rb_node):
            return rb_node
    rb_color_set_black(rb_node)
    return None


cdef object rb_color_try_set_red(
        object rb_node):
    cdef object rb_parent
    rb_parent = rb_get_parent(rb_node)
    if isinstance(rb_parent, Node):
        if rb_color_is_red(rb_node):
            return rb_node
        if rb_color_is_red(rb_parent):
            return rb_node
        if isinstance((<Node>(rb_node)).rb_left, Node):
            if rb_color_is_red((<Node>(rb_node)).rb_left):
                return rb_node
        if isinstance((<Node>(rb_node)).rb_right, Node):
            if rb_color_is_red((<Node>(rb_node)).rb_right):
                return rb_node
        rb_color_set_red(rb_node)
    else:
        rb_color_set_black(rb_node)
    return None


cdef object rb_first(
        object rb_node):
    assert isinstance(rb_node, Node), \
        'isinstance(self(%s), Node) == True' % (rb_node)

    while isinstance((<Node>(rb_node)).rb_left, Node):
        assert rb_get_parent((<Node>(rb_node)).rb_left) is rb_node, \
            'self(%s) is self.rb_left(%s).rb_parent(%s)' \
                % (rb_node,
                   (<Node>(rb_node)).rb_left,
                   rb_get_parent((<Node>(rb_node)).rb_left))
        rb_node = (<Node>(rb_node)).rb_left
    return rb_node


cdef object rb_last(
        object rb_node):
    assert isinstance(rb_node, Node), \
        'isinstance(self(%s), Node) == True' % (rb_node)

    while isinstance((<Node>(rb_node)).rb_right, Node):
        assert rb_get_parent((<Node>(rb_node)).rb_right) is rb_node, \
            'self(%s) is self.rb_right(%s).rb_parent(%s)' \
                % (rb_node,
                   (<Node>(rb_node)).rb_right,
                   rb_get_parent((<Node>(rb_node)).rb_right))
        rb_node = (<Node>(rb_node)).rb_right
    return rb_node


cdef object _replace_node(
        object rb_node_old,
        object rb_node_new):
    cdef object rb_node_parent

    assert isinstance(rb_node_old, Node), \
        'isinstance(self(%s), Node) == True' % (rb_node_old)
    assert isinstance(rb_node_new, Node), \
        'isinstance(self(%s), Node) == True' % (rb_node_new)

    (<Node>(rb_node_new)).rb_parent_color = (<Node>(rb_node_old)).rb_parent_color
    rb_node_parent = rb_get_parent(rb_node_old)
    if isinstance(rb_node_parent, Node):
        if (<Node>(rb_node_parent)).rb_left is rb_node_old:
            (<Node>(rb_node_parent)).rb_left = rb_node_new
        else:
            assert (<Node>(rb_node_parent)).rb_right is rb_node_old, \
                'self(%s) in (self.rb_parent.rb_left(%s), self.rb_parent.rb_right(%s))' \
                    % (rb_node_old,
                      (<Node>(rb_node_parent)).rb_left,
                      (<Node>(rb_node_parent)).rb_right)
            (<Node>(rb_node_parent)).rb_right = rb_node_new
    else:
        assert type(rb_node_parent) is Root, \
            'isinstance(self(%s).rb_parent(%s), Root) == True' \
                % (rb_node_old, rb_node_parent)
        assert (<Root>(rb_node_parent)).rb_node is rb_node_old, \
            'self(%s) is self.rb_parent(%s).rb_node(%s)' \
                % (rb_node_old, rb_node_parent, (<Root>(rb_node_parent)).rb_node)
        (<Root>(rb_node_parent)).rb_node = rb_node_new
        rb_color_set_black(rb_node_new)


cdef Py_ssize_t _check_node(
        object rb_node,
        object idset) except -1:
    cdef Py_ssize_t result
    cdef object rb_node_left
    cdef object rb_node_right

    rb_node_left = id(rb_node)
    assert not PySet_Contains(idset, rb_node_left), \
        'loop detected. self=%s' % (rb_node)
    PySet_Add(idset, rb_node_left)

    rb_node_left = (<Node>(rb_node)).rb_left
    if isinstance(rb_node_left, Node):
        if rb_color_is_red(rb_node_left):
            assert rb_color_is_black(rb_node), \
                'rb_color_is_black(self(%s)) or rb_color_is_black(self.rb_left(%s))' \
                    % (rb_node, rb_node_left)
        assert rb_get_parent(rb_node_left) is rb_node, \
            'self(%s) is self.rb_left(%s).rb_parent(%s)' \
                % (rb_node, rb_node_left, rb_get_parent(rb_node_left))
        result = _check_node(rb_node_left, idset)
    else:
        assert rb_node_left is None, \
            'isinstance(self(%s).rb_left(%s), Node) or (self.rb_left is None)' \
                % (rb_node, rb_node_left)
        # All leaves (NIL) are black.
        result = 1

    rb_node_right = (<Node>(rb_node)).rb_right
    if isinstance(rb_node_right, Node):
        if rb_color_is_red(rb_node_right):
            assert rb_color_is_black(rb_node), \
                'rb_color_is_black(self(%s)) or rb_color_is_black(self.rb_left(%s))' \
                    % (rb_node, rb_node_right)
        assert rb_get_parent(rb_node_right) is rb_node, \
            '(self(%s).rb_right(%s).rb_parent(%s) is self' \
                % (rb_node, rb_node_right, rb_get_parent(rb_node_right))
        rb_node_temp = _check_node(rb_node_right, idset)
        assert result == rb_node_temp, \
            'get_black_count(self(%s).rb_left(%s))->%d == get_black_count(self.rb_right(%s))->%d' \
                % (rb_node, rb_node_left, result, rb_node_right, rb_node_temp)
    else:
        assert rb_node_right is None, \
            'isinstance(self(%s).rb_right(%s), Node) or (self.rb_right is None)' \
                % (rb_node, rb_node_right)
        # All leaves (NIL) are black.
        assert result == 1, \
            'get_black_count(self(%s).rb_left(%s))->%d == get_black_count(self.rb_right(%s))->%d' \
                % (rb_node, rb_node_left, result, rb_node_right, 1)

    if rb_color_is_black(rb_node):
        result += 1
    return result


cdef object _rotate_left(
        object rb_node,
        bint want_reduce_black_node_count):
    '''
    The number of black nodes in the path to the descendant leaves is one more on the right child node than
    on the left child node.
    By rotating the node to the left, the number of black nodes on the left and right child nodes are matched.

    Parameters
    --------
    rb_node: Node
        Specify the node whose left and right child nodes are skewed to the right.
    want_reduce_black_node_count: bint
        Specify True if you want to reduce the number of black nodes in the path
        from the node to the descendant leaf, otherwise specify False.

    Returns
    --------
    Node object:
        Node object that require repeated rotation.
    None:
        When rebalancing is not necessary.
    '''

    cdef object rb_node_left
    cdef object rb_node_right
    cdef object rb_node_right_left
    cdef object rb_node_right_left_left
    cdef object rb_node_right_left_right
    cdef object rb_node_right_right

    while True:
        assert isinstance(rb_node, Node), \
            'isinstance(self(%s), Node) == True' % (rb_node)
        rb_node_left = (<Node>(rb_node)).rb_left
        rb_node_right = (<Node>(rb_node)).rb_right
        assert isinstance(rb_node_right, Node), \
            'isinstance(self.rb_right(%s), Node) == True' % (rb_node_right)
        if isinstance(rb_node_left, Node):
            if rb_color_is_red(rb_node_left):
                # change tree structure
                #      (B:2)    ← color: B: black, R: red, ?: unknown
                #   <R:1> [N+1] ← black node count
                #   [N+0]
                #        ↓
                #      (B:2)
                #   <B:1> [N+1]
                #   [N+0]
                assert rb_color_is_black(rb_node), \
                    'rb_color_is_black(self(%s)) or rb_color_is_black(self.rb_left(%s))' \
                        % (rb_node, rb_node_left)
                rb_color_set_black(rb_node_left)
                # The number of black nodes in the path to the descendant leaves has not changed.
                if want_reduce_black_node_count:
                    rb_node = rb_color_try_set_red(rb_node)
                else:
                    rb_node = None
                break

            # current tree structure
            #      (?:2)
            #   (B:1) [N+2]
            #   [N+0]
            rb_node_right_left = (<Node>(rb_node_right)).rb_left
            assert isinstance(rb_node_right_left, Node), \
                'isinstance(self.rb_right.rb_left(%s), Node) == True' \
                    % (rb_node_right_left)
            if rb_color_is_red(rb_node_right):
                # change tree structure
                #            <B:2>
                #      (B:1)       <R:4>
                #      [N+0]    <B:3> (B:5)
                #               [N+1] [N+1]
                #              ↓
                #            <B:4>
                #      <R:2>       (B:5)
                #   (B:1) <B:3>    [N+1]
                #   [N+0] [N+1]
                assert isinstance((<Node>(rb_node_right)).rb_right, Node), \
                    'isinstance(self.rb_right.rb_right(%s), Node) == True' \
                        % ((<Node>(rb_node_right)).rb_right)
                assert rb_color_is_black(rb_node), \
                    'rb_color_is_black(self(%s))' \
                        % (rb_node)
                assert rb_color_is_black(rb_node_right_left), \
                    'rb_color_is_black(self.rb_right.rb_left(%s))' \
                        % (rb_node_right_left)
                assert rb_color_is_black((<Node>(rb_node_right)).rb_right), \
                    'rb_color_is_black(self.rb_right.rb_right(%s))' \
                        % ((<Node>(rb_node_right)).rb_right)
                _replace_node(rb_node, rb_node_right)
                (<Node>(rb_node_right)).rb_left = rb_node
                #rb_color_set_black(rb_node_right)
                rb_set_parent(rb_node, rb_node_right)
                (<Node>(rb_node)).rb_right = rb_node_right_left
                rb_color_set_red(rb_node)
                rb_set_parent(rb_node_right_left, rb_node)
                # get_black_count(B:1) < get_black_count(B:3)
                rb_node = _rotate_left(rb_node, False)
                if rb_node is None:
                    # The number of black nodes in the path to the descendant leaves has not changed.
                    if want_reduce_black_node_count:
                        rb_node = rb_color_try_set_red(rb_node_right)
                    else:
                        rb_node = None
                    break
                if rb_color_is_red(rb_node):
                    rb_color_set_black(rb_node)
                    # The number of black nodes in the path to the descendant leaves has not changed.
                    if want_reduce_black_node_count:
                        rb_node = rb_color_try_set_red(rb_node_right)
                    else:
                        rb_node = None
                    break
                rb_node = rb_node_right
                continue

            rb_node_right_right = (<Node>(rb_node_right)).rb_right
            assert isinstance(rb_node_right_right, Node), \
                'isinstance(self.rb_right.rb_right, Node), self=%s' % (rb_node)
            if rb_color_is_red(rb_node_right_left):
                # change tree structure
                #                     <?:2>
                #         (B:1)                   <B:6>
                #         [N+0]             <R:4>       [N+1]
                #                        <B:3> <B:5>
                #                        [N+0] [N+0]
                #                       ↓
                #                     <?:4>
                #         <B:2>                   <B:6>
                #   (B:1)       <B:3>       <B:5>       [N+1]
                #   [N+0]       [N+0]       [N+0]
                assert isinstance((<Node>(rb_node_right_left)).rb_left, Node), \
                    'isinstance(self.rb_right.rb_left.rb_left(%s), Node) == True' \
                        % ((<Node>(rb_node_right_left)).rb_left)
                assert rb_color_is_black((<Node>(rb_node_right_left)).rb_left), \
                    'rb_color_is_black(self.rb_right.rb_left.rb_left(%s))' \
                        % ((<Node>(rb_node_right_left)).rb_left)
                assert isinstance((<Node>(rb_node_right_left)).rb_right, Node), \
                    'isinstance(self.rb_right.rb_left.rb_right(%s), Node) == True' \
                        % ((<Node>(rb_node_right)).rb_right)
                assert rb_color_is_black((<Node>(rb_node_right_left)).rb_right), \
                    'rb_color_is_black(self.rb_right.rb_left.rb_right(%s))' \
                        % ((<Node>(rb_node_right_left)).rb_right)
                rb_node_right_left_left = (<Node>(rb_node_right_left)).rb_left
                rb_node_right_left_right = (<Node>(rb_node_right_left)).rb_right
                _replace_node(rb_node, rb_node_right_left)
                (<Node>(rb_node_right_left)).rb_left = rb_node
                (<Node>(rb_node_right_left)).rb_right = rb_node_right
                rb_set_parent(rb_node, rb_node_right_left)
                (<Node>(rb_node)).rb_right = rb_node_right_left_left
                rb_color_set_black(rb_node)
                rb_set_parent(rb_node_right, rb_node_right_left)
                (<Node>(rb_node_right)).rb_left = rb_node_right_left_right
                if isinstance(rb_node_right_left_left, Node):
                    rb_set_parent(rb_node_right_left_left, rb_node)
                if isinstance(rb_node_right_left_right, Node):
                    rb_set_parent(rb_node_right_left_right, rb_node_right)
                # The number of black nodes in the path to the descendant leaves has not changed.
                if want_reduce_black_node_count:
                    rb_node = rb_color_try_set_red(rb_node_right_left)
                else:
                    rb_node = None
                break

            # current tree structure
            #         (?:2)
            #   (B:1)       (?:4)
            #   [N+0]    (B:3) [N+1]
            #            [N+0]
            if rb_color_is_red(rb_node_right_right):
                # change tree structure
                #            <?:2>
                #      (B:1)       <B:4>
                #      [N+0]    <B:3> (R:5)
                #               [N+0] [N+1]
                #              ↓
                #            <B:4>
                #      <R:2>       (R:5)
                #   (B:1) <B:3>    [N+1]
                #   [N+0] [N+0]
                assert isinstance((<Node>(rb_node_right_right)).rb_left, Node), \
                    'isinstance(self.rb_right.rb_right.rb_left(%s), Node) == True' \
                        % ((<Node>(rb_node_right_right)).rb_left)
                assert rb_color_is_black((<Node>(rb_node_right_right)).rb_left), \
                    'rb_color_is_black(self.rb_right.rb_right.rb_left(%s))' \
                        % ((<Node>(rb_node_right_right)).rb_left)
                assert isinstance((<Node>(rb_node_right_right)).rb_right, Node), \
                    'isinstance(self.rb_right.rb_right.rb_right(%s), Node) == True' \
                        % ((<Node>(rb_node_right)).rb_right)
                assert rb_color_is_black((<Node>(rb_node_right_right)).rb_right), \
                    'rb_color_is_black(self.rb_right.rb_right.rb_right(%s))' \
                        % ((<Node>(rb_node_right_right)).rb_right)
                _replace_node(rb_node, rb_node_right)
                (<Node>(rb_node_right)).rb_left = rb_node
                rb_color_set_black(rb_node_right)
                rb_set_parent(rb_node, rb_node_right)
                (<Node>(rb_node)).rb_right = rb_node_right_left
                rb_set_parent(rb_node_right_left, rb_node)
                if rb_color_is_red(rb_node):
                    # The number of black nodes in the path to the descendant leaves has not changed.
                    if want_reduce_black_node_count:
                        rb_node = rb_color_try_set_red(rb_node_right)
                    else:
                        rb_node = None
                else:
                    # The number of black nodes in the path to the descendant leaves has been reduced by one.
                    rb_color_set_red(rb_node)
                    if want_reduce_black_node_count:
                        rb_node = None
                    else:
                        rb_node = rb_color_try_set_black(rb_node_right)
                break

            # change tree structure
            #         <?:2>
            #   (B:1)       <B:4>
            #   [N+0]    (B:3) (B:5)
            #            [N+0] [N+0]
            #           ↓
            #         <B:2>
            #   (B:1)       <R:4>
            #   [N+0]    (B:3) (B:5)
            #            [N+0] [N+0]
            rb_color_set_red(rb_node_right)
            if rb_color_is_red(rb_node):
                # The number of black nodes in the path to the descendant leaves has not changed.
                rb_color_set_black(rb_node)
                if want_reduce_black_node_count:
                    rb_node = rb_color_try_set_red(rb_node)
                else:
                    rb_node = None
                break
            # The number of black nodes in the path to the descendant leaves has been reduced by one.
            if want_reduce_black_node_count:
                rb_node = None
            else:
                rb_node = rb_color_try_set_black(rb_node)
            break

        rb_node_right_left = (<Node>(rb_node_right)).rb_left
        # current tree structure
        #      (?:1)
        #    NIL  [ 2 ]
        if rb_color_is_red(rb_node_right):
            # change tree structure
            #           <B:1>
            #      NIL        <R:3>
            #              <B:2> <B:4>
            #              [ 1 ] [ 1 ]
            #             ↓
            #           <B:3>
            #     <R:1>       <B:4>
            #   NIL  <B:2>    [ 1 ]
            #        [ 1 ]
            assert isinstance(rb_node_right_left, Node), \
                'isinstance(self.rb_right.rb_left(%s), Node)' \
                    % (rb_node_right_left)
            _replace_node(rb_node, rb_node_right)
            (<Node>(rb_node_right)).rb_left = rb_node
            rb_set_parent(rb_node, rb_node_right)
            (<Node>(rb_node)).rb_right = rb_node_right_left
            rb_color_set_red(rb_node)
            rb_set_parent(rb_node_right_left, rb_node)
            # get_black_count(B:1) < get_black_count(B:3)
            rb_node = _rotate_left(rb_node, False)
            if rb_node is None:
                # The number of black nodes in the path to the descendant leaves has not changed.
                if want_reduce_black_node_count:
                    rb_node = rb_color_try_set_red(rb_node_right)
                else:
                    rb_node = None
                break
            if rb_color_is_red(rb_node):
                rb_color_set_black(rb_node)
                # The number of black nodes in the path to the descendant leaves has not changed.
                if want_reduce_black_node_count:
                    rb_node = rb_color_try_set_red(rb_node_right)
                else:
                    rb_node = None
                break
            rb_node = rb_node_right
            continue

        if isinstance(rb_node_right_left, Node):
            # change tree structure
            #             <?:1>
            #      NIL            <B:3>
            #                 <R:2>   [ 1 ]
            #                NIL NIL
            #               ↓
            #             <?:2>
            #     <B:1>           <B:3>
            #  NIL     NIL     NIL    [ 1 ]
            assert rb_color_is_red(rb_node_right_left), \
                'rb_color_is_red(self.rb_right.rb_left(%s)' \
                    % (rb_node_right_left)
            _replace_node(rb_node, rb_node_right_left)
            (<Node>(rb_node_right_left)).rb_left = rb_node
            (<Node>(rb_node_right_left)).rb_right = rb_node_right
            rb_set_parent(rb_node, rb_node_right_left)
            (<Node>(rb_node)).rb_right = None
            rb_color_set_black(rb_node)
            rb_set_parent(rb_node_right, rb_node_right_left)
            (<Node>(rb_node_right)).rb_left = None
            # The number of black nodes in the path to the descendant leaves has not changed.
            if want_reduce_black_node_count:
                rb_node = rb_color_try_set_red(rb_node_right_left)
            else:
                rb_node = None
            break

        # change tree structure
        #           <?:1>
        #      NIL        <B:2>
        #              NIL    [ 1 ]
        #             ↓
        #           <B:2>
        #     <R:1>       [ 1 ]
        #   NIL   NIL
        _replace_node(rb_node, rb_node_right)
        (<Node>(rb_node_right)).rb_left = rb_node
        rb_color_set_black(rb_node_right)
        rb_set_parent(rb_node, rb_node_right)
        (<Node>(rb_node)).rb_right = None
        if rb_color_is_red(rb_node):
            # The number of black nodes in the path to the descendant leaves has not changed.
            if want_reduce_black_node_count:
                # rb_node = rb_color_try_set_red(rb_node_right)
                rb_node = rb_node_right
            else:
                rb_node = None
        else:
            # The number of black nodes in the path to the descendant leaves has been reduced by one.
            rb_color_set_red(rb_node)
            if want_reduce_black_node_count:
                rb_node = None
            else:
                # rb_node = rb_color_try_set_black(rb_node_right)
                rb_node = rb_node_right
        break
    return rb_node


cdef object _rotate_right(
        object rb_node,
        bint want_reduce_black_node_count):
    '''
    The number of black nodes in the path to the descendant leaves is one more on the left child node
    than on the right child node.
    By rotating the node to the right, the number of black nodes on the left and right child nodes are matched.

    Parameters
    --------
    rb_node: Node
        Specify the node whose left and right child nodes are skewed to the left.
    want_reduce_black_node_count: bint
        Specify True if you want to reduce the number of black nodes in the path
        from the node to the descendant leaf, otherwise specify False.

    Returns
    --------
    Node object:
        Node object that require repeated rotation.
    None:
        When rebalancing is not necessary.
    '''

    cdef object rb_node_right
    cdef object rb_node_left
    cdef object rb_node_left_right
    cdef object rb_node_left_right_left
    cdef object rb_node_left_right_right
    cdef object rb_node_left_left

    while True:
        assert isinstance(rb_node, Node), \
            'isinstance(self, Node) == True, self=%s' % (rb_node)
        rb_node_right = (<Node>(rb_node)).rb_right
        rb_node_left = (<Node>(rb_node)).rb_left
        assert isinstance(rb_node_left, Node), \
            'isinstance(self, Node) == True, self=%s' % (rb_node_left)
        if isinstance(rb_node_right, Node):
            if rb_color_is_red(rb_node_right):
                # change tree structure
                #      (B:1)    ← color: B: black, R: red, ?: unknown
                #   [N+1] <R:2> ← black node count
                #         [N+0]
                #        ↓
                #      (B:1)
                #   [N+1] <B:2>
                #         [N+0]
                assert rb_color_is_black(rb_node), \
                    'rb_color_is_black(self(%s)) or rb_color_is_black(self.rb_right(%s))' \
                        % (rb_node, rb_node_right)
                rb_color_set_black(rb_node_right)
                # The number of black nodes in the path to the descendant leaves has not changed.
                if want_reduce_black_node_count:
                    rb_node = rb_color_try_set_red(rb_node)
                else:
                    rb_node = None
                break

            # current tree structure
            #      (?:1)
            #   [N+2] (B:2)
            #         [N+0]
            rb_node_left_right = (<Node>(rb_node_left)).rb_right
            assert isinstance(rb_node_left_right, Node), \
                'isinstance(self.rb_left.rb_right, Node), self=%s' % (rb_node)
            if rb_color_is_red(rb_node_left):
                # change tree structure
                #            <B:4>
                #      <R:2>       <R:5>
                #   <B:1> (B:3)    [N+0]
                #   [N+1] [N+1]
                #              ↓
                #            <B:2>
                #      (B:1)       <R:4>
                #      [N+1]    <B:3> (B:5)
                #               [N+1] [N+0]
                _replace_node(rb_node, rb_node_left)
                (<Node>(rb_node_left)).rb_right = rb_node
                rb_set_parent(rb_node, rb_node_left)
                (<Node>(rb_node)).rb_left = rb_node_left_right
                rb_color_set_red(rb_node)
                rb_set_parent(rb_node_left_right, rb_node)
                # get_black_count(B:3) > get_black_count(B:5)
                rb_node = _rotate_right(rb_node, False)
                if rb_node is None:
                    # The number of black nodes in the path to the descendant leaves has not changed.
                    if want_reduce_black_node_count:
                        rb_node = rb_color_try_set_red(rb_node_left)
                    else:
                        rb_node = None
                    break
                if rb_color_is_red(rb_node):
                    rb_color_set_black(rb_node)
                    # The number of black nodes in the path to the descendant leaves has not changed.
                    if want_reduce_black_node_count:
                        rb_node = rb_color_try_set_red(rb_node_left)
                    else:
                        rb_node = None
                    break
                rb_node = rb_node_left
                continue

            rb_node_left_left = (<Node>(rb_node_left)).rb_left
            assert isinstance(rb_node_left_left, Node), \
                'isinstance(self.rb_left.rb_left(%s), Node) == True' % (rb_node_left_left)
            if rb_color_is_red(rb_node_left_right):
                # change tree structure
                #                     <?:5>
                #         <B:1>                   (B:6)
                #   [N+1]       <R:3>             [N+0]
                #            <B:2> <B:4>
                #            [N+0] [N+0]
                #                       ↓
                #                     <?:3>
                #         <B:1>                   <B:5>
                #   [N+1]       (B:2)       <B:4>       (B:6)
                #               [N+0]       [N+0]       [N+0]
                rb_node_left_right_left = (<Node>(rb_node_left_right)).rb_right
                rb_node_left_right_right = (<Node>(rb_node_left_right)).rb_left
                _replace_node(rb_node, rb_node_left_right)
                (<Node>(rb_node_left_right)).rb_right = rb_node
                (<Node>(rb_node_left_right)).rb_left = rb_node_left
                rb_set_parent(rb_node, rb_node_left_right)
                (<Node>(rb_node)).rb_left = rb_node_left_right_left
                rb_color_set_black(rb_node)
                rb_set_parent(rb_node_left, rb_node_left_right)
                (<Node>(rb_node_left)).rb_right = rb_node_left_right_right
                if isinstance(rb_node_left_right_left, Node):
                    rb_set_parent(rb_node_left_right_left, rb_node)
                if isinstance(rb_node_left_right_right, Node):
                    rb_set_parent(rb_node_left_right_right, rb_node_left)
                # The number of black nodes in the path to the descendant leaves has not changed.
                if want_reduce_black_node_count:
                    rb_node = rb_color_try_set_red(rb_node_left_right)
                else:
                    rb_node = None
                break

            # current tree structure
            #            (?:3)
            #      (B:1)       (B:4)
            #   [N+1] (B:2)    [N+0]
            #         [N+0]
            if rb_color_is_red(rb_node_left_left):
                # change tree structure
                #            <?:4>
                #      <B:2>       (B:5)
                #   (R:1) <B:3>    [N+0]
                #   [N+1] [N+0]
                #              ↓
                #            <B:2>
                #      (R:1)       <R:4>
                #      [N+1]    <B:3> (B:5)
                #               [N+0] [N+1]
                _replace_node(rb_node, rb_node_left)
                (<Node>(rb_node_left)).rb_right = rb_node
                rb_color_set_black(rb_node_left)
                rb_set_parent(rb_node, rb_node_left)
                (<Node>(rb_node)).rb_left = rb_node_left_right
                rb_set_parent(rb_node_left_right, rb_node)
                if rb_color_is_red(rb_node):
                    # The number of black nodes in the path to the descendant leaves has not changed.
                    if want_reduce_black_node_count:
                        rb_node = rb_color_try_set_red(rb_node_left)
                    else:
                        rb_node = None
                else:
                    # The number of black nodes in the path to the descendant leaves has been reduced by one.
                    rb_color_set_red(rb_node)
                    if want_reduce_black_node_count:
                        rb_node = None
                    else:
                        rb_node = rb_color_try_set_black(rb_node_left)
                break

            # change tree structure
            #            <?:4>
            #      <B:2>       (B:5)
            #   (B:1) (B:3)    [N+0]
            #   [N+0] [N+0]
            #              ↓
            #            <B:4>
            #      <R:2>       (B:5)
            #   (B:1) (B:3)    [N+0]
            #   [N+0] [N+0]
            rb_color_set_red(rb_node_left)
            if rb_color_is_red(rb_node):
                # The number of black nodes in the path to the descendant leaves has not changed.
                rb_color_set_black(rb_node)
                if want_reduce_black_node_count:
                    rb_node = rb_color_try_set_red(rb_node)
                else:
                    rb_node = None
            else:
                # The number of black nodes in the path to the descendant leaves has been reduced by one.
                if want_reduce_black_node_count:
                    rb_node = None
                else:
                    rb_node = rb_color_try_set_black(rb_node)
            break

        rb_node_left_right = (<Node>(rb_node_left)).rb_right
        # current tree structure
        #      (?:1)
        #   [ 2 ]  NIL
        if rb_color_is_red(rb_node_left):
            # change tree structure
            #            <B:4>
            #      <R:2>        NIL
            #   <B:1> <B:3>
            #   [ 1 ] [ 1 ]
            #              ↓
            #            <B:2>
            #      <B:1>       <R:4> 
            #      [ 1 ]    <B:3>  NIL
            #               [ 1 ]
            assert isinstance(rb_node_left_right, Node), \
                'isinstance(self.rb_left.rb_right(%s), Node) == True' \
                    % (rb_node_left_right)
            _replace_node(rb_node, rb_node_left)
            (<Node>(rb_node_left)).rb_right = rb_node
            rb_set_parent(rb_node, rb_node_left)
            (<Node>(rb_node)).rb_left = rb_node_left_right
            rb_color_set_red(rb_node)
            rb_set_parent(rb_node_left_right, rb_node)
            # get_black_count(B:3) > 1(NIL)
            rb_node = _rotate_right(rb_node, False)
            if rb_node is None:
                # The number of black nodes in the path to the descendant leaves has not changed.
                if want_reduce_black_node_count:
                    rb_node = rb_color_try_set_red(rb_node_left)
                else:
                    rb_node = None
                break
            if rb_color_is_red(rb_node):
                rb_color_set_black(rb_node)
                # The number of black nodes in the path to the descendant leaves has not changed.
                if want_reduce_black_node_count:
                    rb_node = rb_color_try_set_red(rb_node_left)
                else:
                    rb_node = None
                break
            rb_node = rb_node_left
            continue

        if isinstance(rb_node_left_right, Node):
            assert rb_color_is_red(rb_node_left_right), \
                'rb_color_is_red(self.rb_left.rb_right(%s))' % (rb_node)
            # change tree structure
            #               <?:3>
            #       <B:1>            NIL
            #   [ 1 ]   <R:2>
            #          NIL NIL
            #                 ↓
            #               <?:2>
            #       <B:1>           <B:3>
            #   [ 1 ]    NIL     NIL     NIL
            _replace_node(rb_node, rb_node_left_right)
            (<Node>(rb_node_left_right)).rb_left = rb_node_left
            (<Node>(rb_node_left_right)).rb_right = rb_node
            rb_set_parent(rb_node, rb_node_left_right)
            (<Node>(rb_node)).rb_left = None
            rb_color_set_black(rb_node)
            rb_set_parent(rb_node_left, rb_node_left_right)
            (<Node>(rb_node_left)).rb_right = None
            # The number of black nodes in the path to the descendant leaves has not changed.
            if want_reduce_black_node_count:
                rb_node = rb_color_try_set_red(rb_node_left_right)
            else:
                rb_node = None
            break

        # change tree structure
        #            <?:2>
        #      <B:1>        NIL
        #   [ 1 ]  NIL
        #              ↓
        #            <B:1>
        #      [ 1 ]       <R:2>
        #                NIL   NIL
        _replace_node(rb_node, rb_node_left)
        (<Node>(rb_node_left)).rb_right = rb_node
        rb_color_set_black(rb_node_left)
        rb_set_parent(rb_node, rb_node_left)
        (<Node>(rb_node)).rb_left = None
        if rb_color_is_red(rb_node):
            # The number of black nodes in the path to the descendant leaves has not changed.
            if want_reduce_black_node_count:
                # rb_node = rb_color_try_set_red(rb_node_left)
                rb_node = rb_node_left
            else:
                rb_node = None
        else:
            # The number of black nodes in the path to the descendant leaves has been reduced by one.
            rb_color_set_red(rb_node)
            if want_reduce_black_node_count:
                rb_node = None
            else:
                # rb_node = rb_color_try_set_black(rb_node_left)
                rb_node = rb_node_left
        break

    return rb_node


cdef object _rebalance_remain_black_node_count(
        object rb_node):
    cdef object rb_node_parent

    while isinstance(rb_node, Node):
        rb_node_parent = rb_get_parent(rb_node)
        if isinstance(rb_node_parent, Node):
            if (<Node>(rb_node_parent)).rb_left is rb_node:
                rb_node = _rotate_left(rb_node_parent, False)
            else:
                assert (<Node>(rb_node_parent)).rb_right is rb_node, \
                    'self(%s) in (self.rb_parent.rb_left(%s), self.rb_parent.rb_right(%s)' \
                        % (rb_node,
                        (<Node>(rb_node_parent)).rb_left,
                        (<Node>(rb_node_parent)).rb_right)
                rb_node = _rotate_right(rb_node_parent, False)
        else:
            assert type(rb_node_parent) is Root, \
                'isinstance(self(%s).rb_parent(%s), Root) == True' \
                    % (rb_node, rb_node_parent)
            # rb_node is root node
            rb_color_set_black(rb_node)
            break


cdef object _rebalance_reduce_black_node_count(
        object rb_node):
    cdef object rb_node_parent

    while isinstance(rb_node, Node):
        rb_node_parent = rb_get_parent(rb_node)
        if isinstance(rb_node_parent, Node):
            if (<Node>(rb_node_parent)).rb_left is rb_node:
                rb_node = _rotate_right(rb_node_parent, True)
            else:
                assert (<Node>(rb_node_parent)).rb_right is rb_node, \
                    'self(%s) in (self.rb_parent.rb_left(%s), self.rb_parent.rb_right(%s)' \
                        % (rb_node,
                        (<Node>(rb_node_parent)).rb_left,
                        (<Node>(rb_node_parent)).rb_right)
                rb_node = _rotate_left(rb_node_parent, True)
        else:
            assert type(rb_node_parent) is Root, \
                'isinstance(self(%s).rb_parent(%s), Root) == True' \
                    % (rb_node, rb_node_parent)
            # rb_node is root node
            rb_color_set_black(rb_node)
            break


cdef object _remove_node(
        object rb_node):
    cdef object rb_node_parent
    cdef object rb_node_left
    cdef object rb_node_right
    cdef object rb_node_right_left
    cdef object rb_node_temp

    # removing node
    rb_node_left = (<Node>(rb_node)).rb_left
    rb_node_right = (<Node>(rb_node)).rb_right
    if isinstance(rb_node_left, Node):
        if isinstance(rb_node_right, Node):
            # self.rb_left and self.rb_right exists.
            rb_node_right_left = rb_first(rb_node_right)
            if rb_node_right_left is rb_node_right:
                if rb_color_is_red(rb_node_right):
                    # change tree structure (removing <?:1>)
                    #       <B:1>
                    #   [ 1 ]   <R:2>
                    #          NIL NIL
                    #         ↓
                    #       <B:2>
                    #   [ 1 ]    NIL
                    assert rb_color_is_black(rb_node), \
                        'rb_color_is_black(rb_node(%s))' % (rb_node)
                    _replace_node(rb_node, rb_node_right)
                    (<Node>(rb_node_right)).rb_left = rb_node_left
                    rb_set_parent(rb_node_left, rb_node_right)
                else:
                    # change tree structure (removing <?:1>)
                    #         <?:1>
                    #   [ 2 ]       <B:2>
                    #             NIL  [ 1 ]
                    #           ↓
                    #         <B:2>
                    #   [ 2 ]       [ 1 ]
                    _replace_node(rb_node, rb_node_right)
                    (<Node>(rb_node_right)).rb_left = rb_node_left
                    rb_set_parent(rb_node_left, rb_node_right)
                    if rb_color_is_red(rb_node_right):
                        rb_color_set_black(rb_node_right)
                        _rebalance_reduce_black_node_count(
                            _rotate_right(rb_node_right, True))
                    else:
                        _rebalance_remain_black_node_count(
                            _rotate_right(rb_node_right, False))
            else:
                rb_node_parent = rb_get_parent(rb_node_right_left)
                if rb_color_is_red(rb_node_right_left):
                    # change tree structure (removing <?:1>)
                    #         <?:1>
                    #   [ N ]                  <?:4>
                    #                         .    [N- ]
                    #                        .
                    #                       .
                    #                  <B:3>
                    #              <R:2>   [ 1 ]
                    #             NIL NIL
                    #           ↓
                    #         <?:2>
                    #   [ N ]                  <?:4>
                    #                         .    [N- ]
                    #                        .
                    #                       .
                    #                  <B:3>
                    #               NIL    [ 1 ]
                    assert rb_color_is_black(rb_node_parent), \
                        'rb_color_is_black(rb_first(rb_node.rb_right).rb_parent(%s))' \
                            % (rb_node_parent)
                    (<Node>(rb_node_parent)).rb_left = None
                    _replace_node(rb_node, rb_node_right_left)
                    (<Node>(rb_node_right_left)).rb_left = rb_node_left
                    (<Node>(rb_node_right_left)).rb_right = rb_node_right
                    rb_set_parent(rb_node_left, rb_node_right_left)
                    rb_set_parent(rb_node_right, rb_node_right_left)
                else:
                    # change tree structure (removing <?:1>)
                    #         <?:1>
                    #   [ N ]                       <?:4>
                    #                              .     [N- ]
                    #                            .
                    #                          .
                    #                     <?:3>
                    #               <B:2>       [ 2 ]
                    #             NIL  [ 1 ]
                    #           ↓
                    #         <?:2>
                    #   [ N ]                       <?:4>
                    #                              .     [N- ]
                    #                            .
                    #                          .
                    #                     <B:3>
                    #               [ 1 ]       [ 2 ]
                    rb_node_parent = rb_get_parent(rb_node_right_left)
                    rb_node_temp = (<Node>(rb_node_right_left)).rb_right
                    (<Node>(rb_node_parent)).rb_left = rb_node_temp
                    if isinstance(rb_node_temp, Node):
                        rb_set_parent(rb_node_temp, rb_node_parent)
                    _replace_node(rb_node, rb_node_right_left)
                    (<Node>(rb_node_right_left)).rb_left = rb_node_left
                    (<Node>(rb_node_right_left)).rb_right = rb_node_right
                    rb_set_parent(rb_node_left, rb_node_right_left)
                    rb_set_parent(rb_node_right, rb_node_right_left)
                    if rb_color_is_red(rb_node_parent):
                        rb_color_set_black(rb_node_parent)
                        while True:
                            rb_node_parent = _rotate_left(rb_node_parent, True)
                            if rb_node_parent is None:
                                return
                            if rb_node_parent is (<Node>(rb_node_right_left)).rb_right:
                                _rebalance_reduce_black_node_count(
                                    _rotate_right(rb_node_right_left, True))
                                break
                            rb_node_parent = rb_get_parent(rb_node_parent)
                    else:
                        while True:
                            rb_node_parent = _rotate_left(rb_node_parent, False)
                            if rb_node_parent is None:
                                return
                            if rb_node_parent is (<Node>(rb_node_right_left)).rb_right:
                                _rebalance_remain_black_node_count(
                                    _rotate_right(rb_node_right_left, False))
                                break
                            rb_node_parent = rb_get_parent(rb_node_parent)
        else:
            # self.rb_right is None.
            # change tree structure (removing <B:2>)
            #        <B:2>
            #    <R:1>    NIL
            #   NIL NIL
            #          ↓
            #        <B:1>
            #     NIL     NIL
            assert rb_color_is_red(rb_node_left), \
                'rb_color_is_red(self(%s).rb_left(%s))' \
                    % (rb_node, rb_node_left)
            assert not isinstance((<Node>(rb_node_left)).rb_left, Node), \
                'self(%s).rb_left(%s).rb_left(%s) is None' \
                    % (rb_node, rb_node_left, (<Node>(rb_node_left)).rb_left)
            assert not isinstance((<Node>(rb_node_left)).rb_right, Node), \
                'self(%s).rb_left(%s).rb_right(%s) is None' \
                    % (rb_node, rb_node_left, (<Node>(rb_node_left)).rb_right)
            _replace_node(rb_node, rb_node_left)
    else:
        if isinstance(rb_node_right, Node):
            # self.rb_left is None.
            # change tree structure (removing <B:1>)
            #      <B:1>
            #   NIL    <R:2>
            #         NIL NIL
            #        ↓
            #      <B:2>
            #   NIL     NIL
            assert rb_color_is_red(rb_node_right), \
                'rb_color_is_red(rb_node(%s).rb_right(%s))' \
                    % (rb_node, rb_node_right)
            assert not isinstance((<Node>(rb_node_right)).rb_left, Node), \
                'rb_node(%s).rb_right(%s).rb_left(%s) is None' \
                    % (rb_node, rb_node_right, (<Node>(rb_node_right)).rb_left)
            assert not isinstance((<Node>(rb_node_right)).rb_right, Node), \
                'rb_node(%s).rb_right(%s).rb_right(%s) is None' \
                    % (rb_node, rb_node_right, (<Node>(rb_node_right)).rb_left)
            _replace_node(rb_node, rb_node_right)
        else:
            # self.rb_left and self.rb_right is None.
            rb_node_parent = rb_get_parent(rb_node)
            if isinstance(rb_node_parent, Node):
                if (<Node>(rb_node_parent)).rb_left is rb_node:
                    (<Node>(rb_node_parent)).rb_left = None
                    if rb_color_is_red(rb_node):
                        # change tree structure (removing <R:1>)
                        #        <B:2>
                        #    <R:1>   [ 1 ]
                        #   NIL NIL
                        #          ↓
                        #        <B:2>
                        #     NIL    [ 1 ]
                        assert rb_color_is_black(rb_node_parent), \
                            'rb_color_is_black(rb_node(%s).rb_parent(%s))' \
                                % (rb_node, rb_node_parent)
                    else:
                        # change tree structure (removing <B:1>)
                        #        <?:2>
                        #    <B:1>   [ 2 ]
                        #   NIL NIL
                        #          ↓
                        #        <?:2>
                        #     NIL    [ 2 ]
                        _rebalance_remain_black_node_count(
                            _rotate_left(rb_node_parent, False))
                else:
                    assert (<Node>(rb_node_parent)).rb_right is rb_node, \
                        'self(%s) in (self.rb_parent.rb_left(%s), self.rb_parent.rb_right(%s)' \
                            % (rb_node,
                              (<Node>(rb_node_parent)).rb_left,
                            (<Node>(rb_node_parent)).rb_right)
                    (<Node>(rb_node_parent)).rb_right = None
                    if rb_color_is_red(rb_node):
                        # change tree structure (removing <R:2>)
                        #       <B:1>
                        #   [ 1 ]   <R:2>
                        #          NIL NIL
                        #         ↓
                        #       <B:1>
                        #   [ 1 ]    NIL
                        assert rb_color_is_black(rb_node_parent), \
                            'rb_color_is_black(rb_node(%s).rb_parent(%s))' \
                                % (rb_node, rb_node_parent)
                    else:
                        # change tree structure (removing <B:2>)
                        #       <?:1>
                        #   [ 2 ]   <B:2>
                        #          NIL NIL
                        #         ↓
                        #       <?:1>
                        #   [ 2 ]    NIL
                        _rebalance_remain_black_node_count(
                            _rotate_right(rb_node_parent, False))
            else:
                # removing last node
                assert type(rb_node_parent) is Root, \
                    'isinstance(self(%s).rb_parent(%s), Root) == True' \
                        % (rb_node, rb_node_parent)
                assert (<Root>(rb_node_parent)).rb_node is rb_node, \
                    'self(%s) is self.rb_parent(%s).rb_node(%s)' \
                        % (rb_node,
                           rb_node_parent,
                           (<Root>(rb_node_parent)).rb_node)
                (<Root>(rb_node_parent)).rb_node = None


cdef class Node:
    @property
    def rb_parent(self):
        if (self.rb_parent_color & ~RB_COLOR_MASK) == 0:
            return None
        return rb_get_parent(self)

    @property
    def rb_color(self):
        return (self.rb_parent_color & RB_COLOR_MASK)

    cdef object next_node(self):
        cdef object rb_node
        cdef object rb_node_parent

        if isinstance(self.rb_right, Node):
            rb_node = rb_first(self.rb_right)
        else:
            rb_node = self
            while True:
                rb_node_parent = rb_get_parent(rb_node) 
                if not isinstance(rb_node_parent, Node):
                    rb_node = None
                    break
                if (<Node>(rb_node_parent)).rb_left is rb_node:
                    rb_node = rb_node_parent
                    break
                rb_node = rb_node_parent
        return rb_node

    cdef object previous_node(self):
        cdef object rb_node
        cdef object rb_node_parent

        if isinstance(self.rb_left, Node):
            rb_node = rb_last(self.rb_left)
        else:
            rb_node = self
            while True:
                rb_node_parent = rb_get_parent(rb_node) 
                if not isinstance(rb_node_parent, Node):
                    rb_node = None
                    break
                if (<Node>(rb_node_parent)).rb_right is rb_node:
                    rb_node = rb_node_parent
                    break
                rb_node = rb_node_parent
        return rb_node


    cdef remove_node(self):
        _remove_node(self)
        self.rb_parent_color = 0
        self.rb_left = None
        self.rb_right = None


cdef class Root:
    cdef object check(self):
        cdef object rb_node

        rb_node = self.rb_node
        if isinstance(rb_node, Node):
            assert rb_get_parent(rb_node) is self, \
                'self(%s) is self.rb_node(%s).rb_parent(%s)' \
                    % (self, rb_node, rb_get_parent(rb_node))
            assert rb_color_is_black(rb_node), \
                'rb_color_is_black(self(%s).rb_node(%s))' \
                    % (self, rb_node)
            _check_node(rb_node, set())
        else:
            assert rb_node is None, \
                'isinstance(self(%s).rb_node(%s), Node) or (self.rb_node is None)' \
                    % (self, rb_node)
        return True


    cdef object first_node(self):
        cdef object rb_node

        if isinstance(self.rb_node, Node):
            rb_node = rb_first(self.rb_node)
        else:
            rb_node = None
        return rb_node


    cdef object last_node(self):
        cdef object rb_node

        if isinstance(self.rb_node, Node):
            rb_node = rb_last(self.rb_node)
        else:
            rb_node = None
        return rb_node


    cdef object add_node(
            self,
            object rb_node):
        cdef object rb_node_parent

        rb_node = <Node?>(rb_node)
        # finding nodes
        if isinstance(self.rb_node, Node):
            rb_node_parent = self.rb_node
            # finding location
            while True:
                if rb_node == rb_node_parent:
                    # node found
                    return rb_node_parent
                if rb_node < rb_node_parent:
                    if isinstance((<Node>(rb_node_parent)).rb_left, Node):
                        rb_node_parent = (<Node>(rb_node_parent)).rb_left
                        continue
                    # adding node to rb_parent.rb_left
                    rb_set_parent(rb_node, rb_node_parent)
                    (<Node>(rb_node)).rb_left = None
                    (<Node>(rb_node)).rb_right = None
                    (<Node>(rb_node_parent)).rb_left = rb_node
                    if rb_color_is_black(rb_node_parent):
                        rb_color_set_red(rb_node)
                    else:
                        rb_color_set_black(rb_node)
                        _rebalance_reduce_black_node_count(
                            _rotate_right(rb_node_parent, True))
                else:
                    if isinstance((<Node>(rb_node_parent)).rb_right, Node):
                        rb_node_parent = (<Node>(rb_node_parent)).rb_right
                        continue
                    # adding node to rb_parent.rb_right
                    rb_set_parent(rb_node, rb_node_parent)
                    (<Node>(rb_node)).rb_left = None
                    (<Node>(rb_node)).rb_right = None
                    (<Node>(rb_node_parent)).rb_right = rb_node
                    if rb_color_is_black(rb_node_parent):
                        rb_color_set_red(rb_node)
                    else:
                        rb_color_set_black(rb_node)
                        _rebalance_reduce_black_node_count(
                            _rotate_left(rb_node_parent, True))
                break
        else:
            rb_set_parent(rb_node, self)
            (<Node>(rb_node)).rb_left = None
            (<Node>(rb_node)).rb_right = None
            rb_color_set_black(rb_node)
            self.rb_node = rb_node
        return rb_node


cdef Py_ssize_t get_black_count(
        object rb_node) except -1:
    cdef Py_ssize_t result = 1
    while isinstance(rb_node, Node):
        if rb_color_is_black(rb_node):
            result += 1
        rb_node = rb_get_parent(<Node>(rb_node))
    return result


cdef object do_print_node(
        object rb_node,
        Py_ssize_t indent,
        object prefix):
    if isinstance(rb_node, Node):
        if isinstance((<Node>(rb_node)).rb_left, Node):
            do_print_node((<Node>(rb_node)).rb_left, indent + 1, '.rb_left  = ')
            assert (<Node>((<Node>(rb_node)).rb_left)).rb_parent is rb_node, \
                'self.rb_left(%s).rb_parent(%s) is self(%s)' % (rb_node)
        else:
            print( ( ' ' * (indent + 1)) + '.rb_left  = None, %s' % (get_black_count(rb_node)))
        print( ( ' ' * indent ) + prefix + str(rb_node) )
        if isinstance((<Node>(rb_node)).rb_right, Node):
            do_print_node((<Node>(rb_node)).rb_right, indent + 1, '.rb_right = ')
            assert (<Node>((<Node>(rb_node)).rb_right)).rb_parent is rb_node, \
                'self.rb_right.rb_parent is self, self=%s' % (rb_node)
        else:
            print( ( ' ' * (indent + 1)) + '.rb_right = None, %s' % (get_black_count(rb_node)))
    else:
        print( ( ' ' * indent ) + prefix + str(rb_node) )


cdef object do_print(
        object rb_node):
    cdef object ids = set()
    cdef object rb_parent = rb_node
    while isinstance(rb_parent, Node):
        assert id(rb_parent) not in ids, \
            do_print_node(rb_parent, 0, 'loop detected: rb_node = ')
        ids.add(id(rb_parent))
        rb_parent = (<Node>(rb_parent)).rb_parent
    if type(rb_parent) is Root:
        print('[target: %s]' % rb_node)
        do_print_node((<Root>(rb_parent)).rb_node, 1, '.rb_node = ')
        if isinstance((<Root>(rb_parent)).rb_node, Node):
            assert (<Node>((<Root>(rb_parent)).rb_node)).rb_parent is rb_parent, \
                'self.rb_node.rb_parent is self, self=%s' % (rb_parent)


cdef Py_ssize_t rb_node_count(
            object rb_node) except -1:
    if isinstance(rb_node, Node):
        return 1 + rb_node_count((<Node>rb_node).rb_left) + rb_node_count((<Node>rb_node).rb_right)
    return 0


@cython.auto_pickle(False)
@cython.final
cdef class TestNode(Node):
    cdef object value

    def __cinit__(self, value):
        self.value = value

    def __hash__(self):
        return PyObject_Hash(self.value)

    def __richcmp__(self, other, int opid):
        return PyObject_RichCompare(self.value, (<TestNode?>other).value, opid)

    def __str__(self):
        if rb_color_is_red(self):
            return '<Red, %s>' % (self.value)
        return '<Black, %s>' % (self.value)


def test():
    cdef Root rb_root = Root()
    cdef object randrange
    cdef object value
    cdef object value2
    cdef object data = set()
    cdef Py_ssize_t count
    from random import randrange

    # add test 1
    while len(data) < 4096:
        value = randrange(1048576)
        value = TestNode(value)
        print('adding: %s' % (value))
        data.add(value)
        if rb_root.add_node(value) is value:
            if not rb_root.check():
                print('checking; NG')
                do_print(rb_root)
                exit(1)
        count = rb_node_count(rb_root.rb_node)
        if count != len(data):
            print('incollect node count: %d, %d' % (count, len(data)))
            do_print(rb_root)
            exit(1)

    # testing next node 1
    count = 0
    value = rb_root.first_node()
    assert isinstance(value, Node)
    assert (<Node>(value)).previous_node() is None
    print('rb_root.first_node() -> %s' % (value))
    while True:
        count += 1
        value2 = (<Node>(value)).next_node()
        print('Node.next_node() -> %s' % (value2))
        if value2 is None:
            break
        assert value < value2
        value = value2
    if count != len(data):
        print('incollect node count: %d, %d' % (count, len(data)))

    # testing previous node 1
    count = 0
    value = rb_root.last_node()
    assert isinstance(value, Node)
    assert (<Node>(value)).next_node() is None
    print('rb_root.last_node() -> %s' % (value))
    while True:
        count += 1
        value2 = (<Node>(value)).previous_node()
        print('Node.previous_node() -> %s' % (value2))
        if value2 is None:
            break
        assert value > value2
        value = value2
    if count != len(data):
        print('incollect node count: %d, %d' % (count, len(data)))

    # remove test 1
    for value in tuple(data):
        print('removing %s' % (value))
        (<Node>value).remove_node()
        if not rb_root.check():
            print('checking; NG')
            do_print(rb_root)
            exit(1)
        data.discard(value)
        count = rb_node_count(rb_root.rb_node)
        if count != len(data):
            print('incollect node count: %d, %d' % (count, len(data)))
            do_print(rb_root)
            exit(1)
    assert rb_root.rb_node is None


