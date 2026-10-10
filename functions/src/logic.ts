// Pure decision logic (unit tested in logic.test.ts). No Firebase imports.

export const MAX_RECORDING_SECONDS = 1200;
/** Encoders pad a little; allow a small tolerance before flagging. */
export const DURATION_TOLERANCE_SECONDS = 5;

export interface RecordingSnapshot {
  ownerUid: string;
  title: string;
  status: string;
  revision?: number;
  reviewFeedback?: string | null;
  publishedSermonId?: string | null;
}

export interface PlannedNotification {
  /** Deterministic ID: retries and duplicate trigger deliveries are idempotent. */
  id: string;
  recipientUid: string | 'admins';
  type: string;
  title: string;
  body: string;
  relatedEntityId: string;
}

/** Notifications implied by a recording status change. */
export function recordingNotifications(
  recordingId: string,
  before: RecordingSnapshot | undefined,
  after: RecordingSnapshot | undefined,
): PlannedNotification[] {
  if (!after) return [];
  if (before && before.status === after.status) return [];
  const rev = after.revision ?? 1;
  const base = `${recordingId}_${after.status}_${rev}`;
  const title = `“${after.title}”`;
  switch (after.status) {
    case 'submitted':
      return [
        {
          id: base,
          recipientUid: after.ownerUid,
          type: 'recording_submitted',
          title: 'Recording submitted',
          body: `${title} is in the review queue.`,
          relatedEntityId: recordingId,
        },
        {
          id: `${base}_admin`,
          recipientUid: 'admins',
          type: 'new_submission_for_review',
          title: rev > 1 ? 'Recording resubmitted' : 'New recording to review',
          body: `${title} is waiting for review.`,
          relatedEntityId: recordingId,
        },
      ];
    case 'approved':
      return [{
        id: base, recipientUid: after.ownerUid, type: 'recording_approved',
        title: 'Recording approved', body: `${title} was approved and will be published soon.`,
        relatedEntityId: recordingId,
      }];
    case 'changes_requested':
      return [{
        id: base, recipientUid: after.ownerUid, type: 'recording_changes_requested',
        title: 'Changes requested', body: after.reviewFeedback ?? `The reviewer asked for changes to ${title}.`,
        relatedEntityId: recordingId,
      }];
    case 'rejected':
      return [{
        id: base, recipientUid: after.ownerUid, type: 'recording_rejected',
        title: 'Recording not accepted', body: after.reviewFeedback ?? `${title} was not accepted.`,
        relatedEntityId: recordingId,
      }];
    case 'published':
      return [{
        id: base, recipientUid: after.ownerUid, type: 'recording_published',
        title: 'Your sermon is live', body: `${title} is now in the sermon library.`,
        relatedEntityId: recordingId,
      }];
    default:
      return [];
  }
}

export type DurationVerdict =
  | { ok: true; seconds: number }
  | { ok: false; seconds: number | null; feedback: string };

/** Server-side enforcement of the 20-minute limit from the actual audio. */
export function checkDuration(seconds: number | null | undefined): DurationVerdict {
  if (seconds == null || !Number.isFinite(seconds) || seconds <= 0) {
    return {
      ok: false,
      seconds: null,
      feedback: 'Automatic check: the uploaded audio could not be read. Please record and submit again.',
    };
  }
  if (seconds > MAX_RECORDING_SECONDS + DURATION_TOLERANCE_SECONDS) {
    const mins = Math.round((seconds / 60) * 10) / 10;
    return {
      ok: false,
      seconds,
      feedback: `Automatic check: the audio is ${mins} minutes long. Recordings must be 20 minutes or shorter.`,
    };
  }
  return { ok: true, seconds };
}

/** True when a content document moves out of the public catalogue. */
export function leftPublication(before?: { status?: string }, after?: { status?: string }): boolean {
  return before?.status === 'published' && after?.status !== 'published';
}
