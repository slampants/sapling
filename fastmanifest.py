# fastmanifest.py
#
# Copyright 2016 Facebook, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.
"""
This extension adds fastmanifest, a treemanifest disk cache for speeding up
manifest comparison. It also contains utilities to investigate manifest access
patterns.


Configuration options:

[fastmanifest]
logfile = "" # Filename, is not empty will log access to any manifest
"""
from mercurial import extensions
from mercurial import manifest
from mercurial import revset
from mercurial import util


class manifestaccesslogger(object):
    """Class to log manifest access and confirm our assumptions"""
    def __init__(self, logfile):
        self._logfile = logfile

    def revwrap(self, orig, *args, **kwargs):
        """Wraps manifest.rev and log access"""
        r = orig(*args, **kwargs)
        try:
            with open(self._logfile, "a") as f:
                f.write("%s\n" % r)
        except EnvironmentError:
            pass
        return r


def fastmanifesttocache(repo, subset, x):
    """Revset of the interesting revisions to cache"""
    return repo.revs("not public()")


class fastmanifestcache(object):
    """Cache of fastmanifest"""
    def __contains__(self, key):
        return False

    def __getitem__(self, key):
        return NotImplementedError("not yet available")


class hybridmanifest(object):
    """
    Hybrid manifest that behaves like a lazy manifest.

    Initialized with:
    - loadflat a function to load a flat manifest from disk
    - cache an object with mapping method to work with fast manifest from disk

    For the moment, behaves like a lazymanifest since cachedmanifest is not
    yet available.
    """
    def __init__(self, loadflat, cache=None, node=None):
        self.loadflat = loadflat
        self.cache = cache
        self.node = node

    @util.propertycache
    def _flatmanifest(self):
        k = self.loadflat()
        if isinstance(k, hybridmanifest):
            # See comment in extsetup to see why we have to do that
            k = k.loadflat()
        assert isinstance(k, manifest.manifestdict), type(k)
        return k

    @util.propertycache
    def _cachedmanifest(self):
        return None

    @util.propertycache
    def _incache(self):
        return False

    # Proxy all the manifest methods to the flatmanifest except magic methods
    def __getattr__(self, name):
        return getattr(self._flatmanifest, name)

    # Magic methods should be proxied differently than __getattr__
    # For the moment all methods they all use the _flatmanifest
    def __iter__(self):
        return self._flatmanifest.__iter__()

    def __contains__(self, key):
        return self._flatmanifest.__contains__(key)

    def __getitem__(self, key):
        return self._flatmanifest.__getitem__(key)

    def __setitem__(self, key, val):
        return self._flatmanifest.__setitem__(key, val)

    def __delitem__(self, key):
        return self._flatmanifest.__delitem__(key)

    def __len__(self):
        return self._flatmanifest.__len__()

    def copy(self):
        return hybridmanifest(loadflat=lambda: self._flatmanifest.copy())

    def diff(self, m2, *args, **kwargs):
        # Find _m1 and _m2 of the same type, to provide the fastest computation
        _m1, _m2 = None, None

        if isinstance(m2, hybridmanifest):
            # CACHE HIT
            if self._incache and m2._incache:
                _m1, _m2 = self._cachedmanifestm, m2._cachedmanifest
                # _m1 or _m2 can be None if _incache was True if the cache
                # got garbage collected in the meantime or entry is corrupted
                if not _m1 or not _m2:
                    _m1, _m2 = self._flatmanifest, m2._flatmanifest

            # CACHE MISS
            else:
                _m1, _m2 = self._flatmanifest, m2._flatmanifest
        else:
            # This happens when diffing against a new manifest (like rev -1)
            _m1, _m2 = self._flatmanifest, m2

        assert type(_m1) == type(_m2)
        return _m1.diff(_m2, *args, **kwargs)


class manifestfactory(object):
    def newmanifest(self, orig, *args, **kwargs):
        loadfn = lambda: orig(*args, **kwargs)
        return hybridmanifest(loadflat=loadfn)

    def read(self, orig, *args, **kwargs):
        loadfn = lambda: orig(*args, **kwargs)
        return hybridmanifest(loadflat=loadfn, node=args[1])


def extsetup(ui):
    logfile = ui.config("fastmanifest", "logfile", "")
    factory = manifestfactory()
    if logfile:
        logger = manifestaccesslogger(logfile)
        extensions.wrapfunction(manifest.manifest, 'rev', logger.revwrap)
    # Wraps all the function creating a manifestdict
    # We have to do that because the logic to create manifest can take
    # 7 different codepaths and we want to retain the node information
    # that comes at the top level:
    #
    # read -> _newmanifest ---------------------------> manifestdict
    #
    # readshallowfast -> readshallow -----------------> manifestdict
    #    \                    \------> _newmanifest --> manifestdict
    #    --> readshallowdelta ------------------------> manifestdict
    #         \->readdelta    -------> _newmanifest --> manifestdict
    #             \->slowreaddelta --> _newmanifest --> manifestdict
    #
    # othermethods -----------------------------------> manifestdict
    #
    # We can have hybridmanifest that wraps one hybridmanifest in some
    # codepath. We resolve to the correct flatmanifest when asked in the
    # _flatmanifest method
    #
    # The recursion level is at most 2 because we wrap the two top level
    # functions and _newmanifest (wrapped only for the case of -1)

    extensions.wrapfunction(manifest.manifest, '_newmanifest',
                            factory.newmanifest)
    extensions.wrapfunction(manifest.manifest, 'read', factory.read)
    try:
        extensions.wrapfunction(manifest.manifest, 'readshallowfast',
                                factory.read)
    except AttributeError:
        # The function didn't use to be defined in previous versions of hg
        pass

    revset.symbols['fastmanifesttocache'] = fastmanifesttocache
    revset.safesymbols.add('fastmanifesttocache')
