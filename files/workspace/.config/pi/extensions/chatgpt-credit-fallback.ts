/**
 * ChatGPT credit fallback.
 *
 * Sign in with ChatGPT (`openai`) stops at the plan's shared usage limit with
 * `subscription_sharing_usage_limit_exceeded`, which Pi does not retry. The
 * Codex route (`openai-codex`) continues on the account's ChatGPT credits once
 * the plan limit is used. When a run ends on that error, switch the session to
 * the same model on `openai-codex` and continue the run once. A failure on the
 * Codex route then ends the run as usual, so the switch cannot loop.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const PLAN_LIMIT = /subscription_sharing_usage_limit_exceeded/;
const FALLBACK_PROVIDER = "openai-codex";

export default function (pi: ExtensionAPI) {
	pi.on("agent_before_settle", async (event, ctx) => {
		const model = ctx.model;
		if (event.outcome !== "error" || model?.provider !== "openai") return;
		const last = event.context.contextMessages.findLast((message) => message.role === "assistant");
		if (last?.role !== "assistant" || last.stopReason !== "error" || !PLAN_LIMIT.test(last.errorMessage ?? "")) return;

		const fallback = ctx.modelRegistry.find(FALLBACK_PROVIDER, model.id);
		if (!fallback || !(await pi.setModel(fallback))) {
			ctx.ui.notify(`ChatGPT plan limit reached; ${FALLBACK_PROVIDER}/${model.id} is unavailable (missing model or login).`, "error");
			return;
		}
		ctx.ui.notify(`ChatGPT plan limit reached; continuing on ${FALLBACK_PROVIDER}/${model.id} with ChatGPT credits.`, "warning");
		return {
			continue: true,
			entries: [
				{
					type: "custom_message",
					customType: "chatgpt-credit-fallback",
					content: `The ChatGPT plan limit was reached, so this session switched to ${FALLBACK_PROVIDER}/${model.id}, which continues on ChatGPT credits. Continue the interrupted work.`,
					display: true,
				},
			],
		};
	});
}
