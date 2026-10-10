import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { checkDuration, leftPublication, recordingNotifications } from './logic';

const rec = (status: string, extra: object = {}) => ({ ownerUid: 'alice', title: 'Grace', status, revision: 1, ...extra });

describe('recordingNotifications', () => {
  it('notifies owner and admins on submission', () => {
    const notes = recordingNotifications('r1', undefined, rec('submitted'));
    assert.deepEqual(notes.map((n) => n.recipientUid), ['alice', 'admins']);
    assert.equal(notes[0].id, 'r1_submitted_1');
  });

  it('is silent when status is unchanged (e.g. duration correction)', () => {
    assert.deepEqual(recordingNotifications('r1', rec('submitted'), rec('submitted')), []);
  });

  it('includes reviewer feedback for change requests', () => {
    const [n] = recordingNotifications('r1', rec('under_review'), rec('changes_requested', { reviewFeedback: 'Trim intro' }));
    assert.equal(n.type, 'recording_changes_requested');
    assert.equal(n.body, 'Trim intro');
  });

  it('uses revision in IDs so resubmissions notify again', () => {
    const [a] = recordingNotifications('r1', rec('changes_requested'), rec('submitted', { revision: 2 }));
    assert.equal(a.id, 'r1_submitted_2');
  });

  it('does not notify on under_review', () => {
    assert.deepEqual(recordingNotifications('r1', rec('submitted'), rec('under_review')), []);
  });
});

describe('checkDuration', () => {
  it('accepts up to 20 minutes plus tolerance', () => {
    assert.equal(checkDuration(1200).ok, true);
    assert.equal(checkDuration(1204).ok, true);
  });
  it('flags longer audio', () => {
    const v = checkDuration(1500);
    assert.equal(v.ok, false);
  });
  it('flags unreadable audio', () => {
    assert.equal(checkDuration(null).ok, false);
    assert.equal(checkDuration(0).ok, false);
    assert.equal(checkDuration(Number.NaN).ok, false);
  });
});

describe('leftPublication', () => {
  it('detects unpublish and archive', () => {
    assert.equal(leftPublication({ status: 'published' }, { status: 'unpublished' }), true);
    assert.equal(leftPublication({ status: 'published' }, { status: 'archived' }), true);
    assert.equal(leftPublication({ status: 'draft' }, { status: 'published' }), false);
    assert.equal(leftPublication({ status: 'published' }, { status: 'published' }), false);
  });
});
