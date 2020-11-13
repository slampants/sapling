# Copyright (c) Facebook, Inc. and its affiliates.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License found in the LICENSE file in the root
# directory of this source tree.

  $ . "${TEST_FIXTURES}/library.sh"

setup configuration
  $ default_setup_pre_blobimport "blob_files"
  hg repo
  o  C [draft;rev=2;26805aba1e60]
  │
  o  B [draft;rev=1;112478962961]
  │
  o  A [draft;rev=0;426bada5c675]
  $
  $ blobimport repo-hg/.hg repo --derived-data-type=changeset_info --derived-data-type=fsnodes --derived-data-type=unodes

check blobstore numbers, walk will do some more steps for mappings
  $ BLOBPREFIX="$TESTTMP/blobstore/blobs/blob-repo0000"
  $ BONSAICOUNT=$(ls $BLOBPREFIX.changeset.* $BLOBPREFIX.content.* $BLOBPREFIX.content_metadata.* | wc -l)
  $ echo "$BONSAICOUNT"
  9
  $ HGCOUNT=$(ls $BLOBPREFIX.* | grep -E '.(filenode_lookup|hgchangeset|hgfilenode|hgmanifest).' | wc -l)
  $ echo "$HGCOUNT"
  12
  $ BLOBCOUNT=$(ls $BLOBPREFIX.* | grep -v .alias. | wc -l)
  $ echo "$BLOBCOUNT"
  39

count-objects, bonsai core data.  total nodes is BONSAICOUNT plus one for the root bookmark step.
  $ mononoke_walker --storage-id=blobstore --readonly-storage scrub -q --bookmark master_bookmark -I bonsai 2>&1 | strip_glog
  Walking roots * (glob)
  Walking edge types [BonsaiChangesetToBonsaiParent, BonsaiChangesetToFileContent, BookmarkToBonsaiChangeset]
  Walking node types [BonsaiChangeset, Bookmark, FileContent]
  Final count: (7, 7)
  Bytes/s,* (glob)
  * Type:Walked,Checks,Children BonsaiChangeset:3,* Bookmark:1,1,1 FileContent:3,3,0 (glob)

count-objects, shallow, bonsai only.  No parents, expect just one of each node type. Also exclude FsnodeToFileContent to keep the test intact
  $ mononoke_walker --storage-id=blobstore --readonly-storage scrub -q --bookmark master_bookmark -I shallow -X hg -x BonsaiHgMapping -X FsnodeToFileContent 2>&1 | strip_glog
  Walking roots * (glob)
  Walking edge types [AliasContentMappingToFileContent, BonsaiChangesetToBonsaiFsnodeMapping, BonsaiChangesetToFileContent, BonsaiFsnodeMappingToRootFsnode, BookmarkToBonsaiChangeset, FileContentMetadataToGitSha1Alias, FileContentMetadataToSha1Alias, FileContentMetadataToSha256Alias, FileContentToFileContentMetadata, FsnodeToChildFsnode]
  Walking node types [AliasContentMapping, BonsaiChangeset, BonsaiFsnodeMapping, Bookmark, FileContent, FileContentMetadata, Fsnode]
  Final count: (9, 9)
  Bytes/s,* (glob)
  * Type:Walked,Checks,Children AliasContentMapping:3,3,0 BonsaiChangeset:1,1,3 BonsaiFsnodeMapping:1,1,1 Bookmark:1,1,1 FileContent:1,1,0 FileContentMetadata:1,0,3 Fsnode:1,1,0 (glob)

count-objects, hg only. total nodes is HGCOUNT plus 1 for the root bookmark step, plus 1 for mapping from bookmark to hg. plus 3 for filenode (same blob as envelope)
  $ mononoke_walker --storage-id=blobstore --readonly-storage scrub -q --bookmark master_bookmark -I hg 2>&1 | strip_glog
  Walking roots * (glob)
  Walking edge types [BonsaiHgMappingToHgChangeset, BookmarkToBonsaiHgMapping, HgChangesetToHgManifest, HgChangesetToHgParent, HgFileEnvelopeToFileContent, HgFileNodeToHgCopyfromFileNode, HgFileNodeToHgParentFileNode, HgFileNodeToLinkedHgChangeset, HgManifestToChildHgManifest, HgManifestToHgFileEnvelope, HgManifestToHgFileNode]
  Walking node types [BonsaiHgMapping, Bookmark, FileContent, HgChangeset, HgFileEnvelope, HgFileNode, HgManifest]
  Final count: (17, 17)
  Bytes/s,* (glob)
  * Type:Walked,Checks,Children BonsaiHgMapping:1,1,1 Bookmark:1,1,1 FileContent:3,3,0 HgChangeset:3,*,5 HgFileEnvelope:3,*,3 HgFileNode:3,*,0 HgManifest:3,3,6 (glob)

count-objects, default shallow walk across bonsai and hg data, but exclude HgFileEnvelope so that we can test that we visit FileContent from fsnodes
  $ mononoke_walker --storage-id=blobstore --readonly-storage scrub -q --bookmark master_bookmark -I shallow -x HgFileEnvelope 2>&1 | strip_glog
  Walking roots * (glob)
  Walking edge types [AliasContentMappingToFileContent, BonsaiChangesetToBonsaiFsnodeMapping, BonsaiChangesetToBonsaiHgMapping, BonsaiChangesetToFileContent, BonsaiFsnodeMappingToRootFsnode, BonsaiHgMappingToHgChangeset, BookmarkToBonsaiChangeset, FileContentMetadataToGitSha1Alias, FileContentMetadataToSha1Alias, FileContentMetadataToSha256Alias, FileContentToFileContentMetadata, FsnodeToChildFsnode, FsnodeToFileContent, HgChangesetToHgManifest, HgManifestToChildHgManifest, HgManifestToHgFileNode]
  Walking node types [AliasContentMapping, BonsaiChangeset, BonsaiFsnodeMapping, BonsaiHgMapping, Bookmark, FileContent, FileContentMetadata, Fsnode, HgChangeset, HgFileNode, HgManifest]
  Final count: (25, 25)
  Bytes/s,* (glob)
  * Type:Walked,Checks,Children AliasContentMapping:9,9,0 BonsaiChangeset:1,1,4 BonsaiFsnodeMapping:1,1,1 BonsaiHgMapping:1,1,1 Bookmark:1,1,1 FileContent:3,*,0 FileContentMetadata:3,0,9 Fsnode:1,1,4 HgChangeset:1,1,1 HgFileNode:3,3,* HgManifest:1,1,3 (glob)

count-objects, default shallow walk across bonsai and hg data, including mutable
  $ mononoke_walker --storage-id=blobstore --readonly-storage scrub -q --bookmark master_bookmark -I shallow -I marker 2>&1 | strip_glog
  Walking roots * (glob)
  Walking edge types [AliasContentMappingToFileContent, BonsaiChangesetToBonsaiFsnodeMapping, BonsaiChangesetToBonsaiHgMapping, BonsaiChangesetToBonsaiPhaseMapping, BonsaiChangesetToFileContent, BonsaiFsnodeMappingToRootFsnode, BonsaiHgMappingToHgChangeset, BookmarkToBonsaiChangeset, FileContentMetadataToGitSha1Alias, FileContentMetadataToSha1Alias, FileContentMetadataToSha256Alias, FileContentToFileContentMetadata, FsnodeToChildFsnode, FsnodeToFileContent, HgChangesetToHgManifest, HgFileEnvelopeToFileContent, HgManifestToChildHgManifest, HgManifestToHgFileEnvelope, HgManifestToHgFileNode]
  Walking node types [AliasContentMapping, BonsaiChangeset, BonsaiFsnodeMapping, BonsaiHgMapping, BonsaiPhaseMapping, Bookmark, FileContent, FileContentMetadata, Fsnode, HgChangeset, HgFileEnvelope, HgFileNode, HgManifest]
  Final count: (29, 29)
  Bytes/s,* (glob)
  * Type:Walked,Checks,Children AliasContentMapping:9,9,0 BonsaiChangeset:1,1,5 BonsaiFsnodeMapping:1,1,1 BonsaiHgMapping:1,1,1 BonsaiPhaseMapping:1,1,0 Bookmark:1,1,1 FileContent:3,*,0 FileContentMetadata:3,0,9 Fsnode:1,1,* HgChangeset:1,1,1 HgFileEnvelope:3,3,* HgFileNode:3,3,0 HgManifest:1,1,6 (glob)

count-objects, default shallow walk across bonsai and hg data, including mutable for all public heads
  $ mononoke_walker --storage-id=blobstore --readonly-storage scrub -q --walk-root PublishedBookmarks -I shallow -I marker 2>&1 | strip_glog
  Walking roots * (glob)
  Walking edge types [AliasContentMappingToFileContent, BonsaiChangesetToBonsaiFsnodeMapping, BonsaiChangesetToBonsaiHgMapping, BonsaiChangesetToBonsaiPhaseMapping, BonsaiChangesetToFileContent, BonsaiFsnodeMappingToRootFsnode, BonsaiHgMappingToHgChangeset, FileContentMetadataToGitSha1Alias, FileContentMetadataToSha1Alias, FileContentMetadataToSha256Alias, FileContentToFileContentMetadata, FsnodeToChildFsnode, FsnodeToFileContent, HgChangesetToHgManifest, HgFileEnvelopeToFileContent, HgManifestToChildHgManifest, HgManifestToHgFileEnvelope, HgManifestToHgFileNode, PublishedBookmarksToBonsaiChangeset, PublishedBookmarksToBonsaiHgMapping]
  Walking node types [AliasContentMapping, BonsaiChangeset, BonsaiFsnodeMapping, BonsaiHgMapping, BonsaiPhaseMapping, FileContent, FileContentMetadata, Fsnode, HgChangeset, HgFileEnvelope, HgFileNode, HgManifest, PublishedBookmarks]
  Final count: (30, 30)
  Bytes/s,* (glob)
  * Type:Walked,Checks,Children AliasContentMapping:9,9,0 BonsaiChangeset:1,1,5 BonsaiFsnodeMapping:1,1,1 BonsaiHgMapping:2,2,1 BonsaiPhaseMapping:1,1,0 FileContent:3,*,0 FileContentMetadata:3,0,9 Fsnode:1,1,* HgChangeset:1,*,1 HgFileEnvelope:3,*,* HgFileNode:3,3,0 HgManifest:1,1,6 PublishedBookmarks:1,1,2 (glob)

count-objects, shallow walk across bonsai and changeset_info
  $ mononoke_walker --storage-id=blobstore --readonly-storage scrub -q --bookmark master_bookmark -I shallow -i bonsai -i derived_changeset_info 2>&1 | strip_glog
  Walking roots * (glob)
  Walking edge types [BonsaiChangesetInfoMappingToChangesetInfo, BonsaiChangesetToBonsaiChangesetInfoMapping, BookmarkToBonsaiChangeset]
  Walking node types [BonsaiChangeset, BonsaiChangesetInfoMapping, Bookmark, ChangesetInfo]
  Final count: (4, 4)
  Bytes/s,* (glob)
  * Type:Walked,Checks,Children BonsaiChangeset:1,* BonsaiChangesetInfoMapping:1,* Bookmark:1,* ChangesetInfo:1,* (glob)

count-objects, deep walk across bonsai and changeset_info
  $ mononoke_walker --storage-id=blobstore --readonly-storage scrub -q --bookmark master_bookmark -I deep -i bonsai -i derived_changeset_info 2>&1 | strip_glog
  Walking roots * (glob)
  Walking edge types [BonsaiChangesetInfoMappingToChangesetInfo, BonsaiChangesetToBonsaiChangesetInfoMapping, BonsaiChangesetToBonsaiParent, BookmarkToBonsaiChangeset, ChangesetInfoToChangesetInfoParent]
  Walking node types [BonsaiChangeset, BonsaiChangesetInfoMapping, Bookmark, ChangesetInfo]
  Final count: (10, 10)
  Bytes/s,* (glob)
  * Type:Walked,Checks,Children BonsaiChangeset:3,* BonsaiChangesetInfoMapping:3,* Bookmark:1,* ChangesetInfo:3,* (glob)

count-objects, shallow walk across bonsai and unodes
  $ mononoke_walker --storage-id=blobstore --readonly-storage scrub -q --bookmark master_bookmark -I shallow -i bonsai -i derived_unodes -i FileContent -X BonsaiChangesetToFileContent 2>&1 | strip_glog
  Walking roots * (glob)
  Walking edge types [BonsaiChangesetToBonsaiUnodeMapping, BonsaiUnodeMappingToRootUnodeManifest, BookmarkToBonsaiChangeset, UnodeFileToFileContent, UnodeManifestToUnodeFileChild, UnodeManifestToUnodeManifestChild]
  Walking node types [BonsaiChangeset, BonsaiUnodeMapping, Bookmark, FileContent, UnodeFile, UnodeManifest]
  Final count: (10, 10)
  Bytes/s,* (glob)
  * Type:Walked,Checks,Children BonsaiChangeset:1,* BonsaiUnodeMapping:1,* Bookmark:1,1,1 FileContent:3,* UnodeFile:3,* UnodeManifest:1,* (glob)

count-objects, deep walk across bonsai and unodes
  $ mononoke_walker --storage-id=blobstore --readonly-storage scrub -q --bookmark master_bookmark -I deep -i bonsai -i derived_unodes -X BonsaiChangesetToBonsaiParent 2>&1 | strip_glog
  Walking roots * (glob)
  Walking edge types [BonsaiChangesetToBonsaiUnodeMapping, BonsaiUnodeMappingToRootUnodeManifest, BookmarkToBonsaiChangeset, UnodeFileToLinkedBonsaiChangeset, UnodeManifestToLinkedBonsaiChangeset, UnodeManifestToUnodeFileChild, UnodeManifestToUnodeManifestChild, UnodeManifestToUnodeManifestParent]
  Walking node types [BonsaiChangeset, BonsaiUnodeMapping, Bookmark, UnodeFile, UnodeManifest]
  Final count: (13, 13)
  Bytes/s,* (glob)
  * Type:Walked,Checks,Children BonsaiChangeset:3,* BonsaiUnodeMapping:3,* Bookmark:1,1,1 UnodeFile:3,* UnodeManifest:3,* (glob)
