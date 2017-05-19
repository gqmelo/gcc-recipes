#!/usr/bin/env python
import os
import sys
import textwrap
import pytest

def obtain_environ(commands, *args, **kwargs):
    import subprocess
    out = subprocess.check_output(commands, *args, **kwargs)
    if sys.version_info >= (3, 0, 0):
        out = out.decode('utf-8')
        out = out.lstrip('environ')
        out = 'dict' + out
    return eval(out)


gcc_libs_path = os.path.expandvars('$PREFIX/lib/gcc-libs')
activate_script = os.path.expandvars('$PREFIX/etc/conda/activate.d/activate-gcc-libs.sh')
deactivate_script = os.path.expandvars('$PREFIX/etc/conda/deactivate.d/deactivate-gcc-libs.sh')

@pytest.mark.parametrize(
    'original_ld_library_path, expected_ld_library_path',
    [
        ('', '{}:'.format(gcc_libs_path)),
        (
            '/usr/lib:/lib64:/home/user/lib',
            '{}:/usr/lib:/lib64:/home/user/lib'.format(gcc_libs_path),
        ),
    ]
)
def test_activate(original_ld_library_path, expected_ld_library_path):
    environ = os.environ.copy()
    environ['LD_LIBRARY_PATH'] = original_ld_library_path
    command = textwrap.dedent('''
        source {activate_script}
        python -c "import os; print(os.environ)"
    ''').format(**globals())
    obtained_environ = obtain_environ(['bash', '-exc', command], env=environ)

    assert obtained_environ.get('LD_LIBRARY_PATH') == expected_ld_library_path


@pytest.mark.parametrize(
    'original_ld_preload, expected_ld_preload',
    [
        ('', 'libstdc++.so.6 '),
        # LD_PRELOAD accepts both whitespace and colon as separator
        (
            '/usr/lib/libfoo.so:/lib64/libbar.so:libz.so',
            'libstdc++.so.6 /usr/lib/libfoo.so:/lib64/libbar.so:libz.so',
        ),
        (
            '/usr/lib/libfoo.so:/lib64/libbar.so libz.so',
            'libstdc++.so.6 /usr/lib/libfoo.so:/lib64/libbar.so libz.so',
        ),
        (
            '/usr/lib/libfoo.so /lib64/libbar.so libz.so',
            'libstdc++.so.6 /usr/lib/libfoo.so /lib64/libbar.so libz.so',
        ),
    ]
)
def test_ld_preload_on_activate(original_ld_preload, expected_ld_preload):
    environ = os.environ.copy()
    environ['LD_PRELOAD'] = original_ld_preload
    command = textwrap.dedent('''
        source {activate_script}
        python -c "import os; print(os.environ)"
    ''').format(**globals())
    obtained_environ = obtain_environ(['bash', '-exc', command], env=environ)

    assert obtained_environ.get('LD_PRELOAD') == expected_ld_preload


@pytest.mark.parametrize(
    'original_ld_library_path, expected_ld_library_path',
    [
        ('', ''),
        (
            '{}:/usr/lib:/lib64:/home/user/lib'.format(gcc_libs_path),
            '/usr/lib:/lib64:/home/user/lib'
        ),
        (
            '/usr/lib:{}:/lib64:/home/user/lib:'.format(gcc_libs_path),
            '/usr/lib:/lib64:/home/user/lib'
        ),
        (
            '/usr/lib:/lib64:/home/user/lib:{}'.format(gcc_libs_path),
            '/usr/lib:/lib64:/home/user/lib'
        ),
        (
            '/usr/lib:{}:/lib64:{}:/home/user/lib:{}'.format(gcc_libs_path, gcc_libs_path, gcc_libs_path),
            '/usr/lib:/lib64:/home/user/lib'
        ),
    ]
)
def test_deactivate(original_ld_library_path, expected_ld_library_path):
    environ = os.environ.copy()
    environ['LD_LIBRARY_PATH'] = original_ld_library_path
    command = textwrap.dedent('''
        source {activate_script}
        source {deactivate_script}
        python -c "import os; print(os.environ)"
    ''').format(**globals())
    obtained_environ = obtain_environ(['bash', '-exc', command], env=environ)

    assert obtained_environ.get('LD_LIBRARY_PATH', '') == expected_ld_library_path


@pytest.mark.parametrize(
    'original_ld_preload, expected_ld_preload',
    [
        ('', ''),
        # LD_PRELOAD accepts both whitespace and colon as separator
        # When deactivating we normalize to whitespace.
        (
            'libstdc++.so.6 /usr/lib/libfoo.so:/lib64/libbar.so:libz.so',
            '/usr/lib/libfoo.so /lib64/libbar.so libz.so',
        ),
        (
            '/usr/lib/libfoo.so libstdc++.so.6 /lib64/libbar.so:libz.so',
            '/usr/lib/libfoo.so /lib64/libbar.so libz.so',
        ),
        (
            '/usr/lib/libfoo.so /lib64/libbar.so libz.so:libstdc++.so.6',
            '/usr/lib/libfoo.so /lib64/libbar.so libz.so',
        ),
        (
            'libstdc++.so.6 /usr/lib/libfoo.so libstdc++.so.6 /lib64/libbar.so libz.so:libstdc++.so.6',
            '/usr/lib/libfoo.so /lib64/libbar.so libz.so',
        ),
    ]
)
def test_ld_preload_on_deactivate(original_ld_preload, expected_ld_preload):
    environ = os.environ.copy()
    environ['LD_PRELOAD'] = original_ld_preload
    command = textwrap.dedent('''
        source {activate_script}
        source {deactivate_script}
        python -c "import os; print(os.environ)"
    ''').format(**globals())
    obtained_environ = obtain_environ(['bash', '-exc', command], env=environ)

    assert obtained_environ.get('LD_PRELOAD', '') == expected_ld_preload


@pytest.mark.parametrize(
    'original_ld_library_path',
    [
        '',
        '/usr/lib:/lib64:/home/user/lib',
    ]
)
def test_activate_deactivate(original_ld_library_path):
    environ = os.environ.copy()
    environ['LD_LIBRARY_PATH'] = original_ld_library_path
    command = textwrap.dedent('''
        source {activate_script}
        source {deactivate_script}
        python -c "import os; print(os.environ)"
    ''').format(**globals())
    obtained_environ = obtain_environ(['bash', '-exc', command], env=environ)

    assert obtained_environ.get('LD_LIBRARY_PATH', '') == original_ld_library_path


@pytest.mark.parametrize(
    'original_ld_preload',
    [
        '',
        '/usr/lib/libfoo.so:/lib64/libbar.so:libz.so',
        '/usr/lib/libfoo.so:/lib64/libbar.so libz.so',
        '/usr/lib/libfoo.so /lib64/libbar.so libz.so',
    ]
)
def test_ld_preload_on_activate_deactivate(original_ld_preload):
    environ = os.environ.copy()
    environ['LD_PRELOAD'] = original_ld_preload
    command = textwrap.dedent('''
        source {activate_script}
        source {deactivate_script}
        python -c "import os; print(os.environ)"
    ''').format(**globals())
    obtained_environ = obtain_environ(['bash', '-exc', command], env=environ)

    assert obtained_environ.get('LD_PRELOAD', '') == original_ld_preload.replace(':', ' ')


if __name__ == '__main__':
    sys.exit(pytest.main([__file__, '-vvv']))
