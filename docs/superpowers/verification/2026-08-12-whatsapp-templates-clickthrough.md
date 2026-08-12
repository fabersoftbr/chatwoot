# WhatsApp template creation — human verification protocol

_Branch `feat/whatsapp-templates`. Nothing below has ever been run against the live Meta Graph API._


**Everything in this feature was verified against WebMock stubs that encode what Meta's own documentation says the Graph API returns — never against the live Graph API.** No Meta WhatsApp Business Account (WABA) was reachable from this environment at any point. The click-through list below is the first real contact with Meta and must be run by a human with an actual WABA connected to a Chatwoot WhatsApp Cloud inbox, as an account Administrator.

1. **Open the tab.** As an Administrator, go to Inbox Settings for a WhatsApp Cloud inbox → the "WhatsApp Templates" tab should be visible and show either an empty state or a table of existing templates pulled from Meta.
   - Failure would look like: tab missing entirely (wrong channel detection), a blank/broken table, or a network error alert on load.

2. **Create a template with no variables.** Click "Add template", fill in a unique lowercase/underscore name (e.g. `order_confirmed_no_vars`), pick a language and category, write a body with no `{{1}}` placeholders, submit.
   - Expect: success alert, dialog closes, the new template appears in the table, likely with status `PENDING` (Meta reviews templates asynchronously — it will not show `APPROVED` immediately).
   - Failure would look like: a validation error blocking submission even though the body looks valid, or a 4xx/5xx alert showing Meta's raw error text (e.g. permission/scope errors, malformed payload complaints).

3. **Create a template with two variables.** New template, body containing `{{1}}` and `{{2}}` in order, fill in the two example values the form prompts for, submit.
   - Expect: same success path as above; the template's body renders with the placeholders and both examples were required before the Submit button became enactable.
   - Failure would look like: the numbering being non-sequential (e.g. only `{{2}}` used) silently passing client validation when it shouldn't, or Meta rejecting the payload for a reason not surfaced to the screen.

4. **Create a template with a duplicate name.** Reuse the exact name from step 2 (same name — language can differ or match), submit.
   - Expect: **Meta's own error text appears on screen verbatim**, unmodified/untranslated (per `render_meta_error`, the controller passes through `error.message` from Meta's response body). It will not be a generic Chatwoot validation message.
   - Failure would look like: a generic "Template request failed" fallback instead of Meta's specific wording (would mean `result[:body]` didn't carry the expected `error.message` shape), or the duplicate silently succeeding.

5. **Delete a template.** Click delete on any existing template, confirm in the dialog.
   - Expect: success alert, the row disappears, and the table refreshes from a fresh `sync_templates` call (not just an optimistic client-side removal).
   - Failure would look like: the row staying after confirm, or the delete succeeding against Meta but the UI not reflecting it (stale `message_templates` on the inbox).

6. **Confirm an agent account cannot use the tab's actions.** Log in as a non-Administrator Agent with access to the same inbox. Note: Chatwoot's inbox settings routes are typically Administrator-only at the route level, so an Agent may not even reach this settings page — if the Agent role has no menu path into Inbox Settings at all, that already satisfies this check. If somehow reached (e.g. direct URL), attempting create/delete should fail with an authorization error, because the controller calls `authorize @inbox, :update?` (Administrator-level policy) before doing anything else.
   - Failure would look like: an Agent successfully creating or deleting a template — meaning the `authorize` check was bypassed somewhere.

7. **Confirm the tab is absent on a 360dialog inbox.** Open Inbox Settings for a WhatsApp inbox provisioned via 360dialog (not Cloud API).
   - Expect: no "WhatsApp Templates" tab in the tab list at all (`Settings.vue` only adds the tab when `isAWhatsAppCloudChannel` is true).
   - Failure would look like: the tab appearing and then erroring out when opened (would mean the gate condition is wrong or too loose).

8. **Confirm the tab is absent on a Twilio inbox.** Open Inbox Settings for a Twilio-backed WhatsApp/SMS inbox.
   - Expect: same as above — no "WhatsApp Templates" tab.
   - Failure would look like: the tab appearing on a non-Cloud channel type.

9. **Delete a template that exists in more than one language.** Create (or find) the same template name in two languages, then delete one row.
   - Expect: only that language disappears. The sibling language survives.
   - This is the check that matters most. Deleting by name alone makes Meta remove **every** language version of that name, and Meta then blocks reuse of the name for 30 days. The fix passes the template's Meta `id` as `hsm_id` so the delete targets exactly one row. If the sibling vanishes too, `hsm_id` is not reaching the wire.
   - If a row has no `id` (older synced payloads), the confirmation dialog says so explicitly and the delete WILL remove all languages. That is intended and warned about, not a bug.

10. **Delete the last remaining template.**
    - Expect: the list ends up genuinely empty, and stays empty after a full page reload.
    - Failure would look like: the deleted template reappearing after reload — meaning a failed or empty refresh was mistaken for "nothing to update".
