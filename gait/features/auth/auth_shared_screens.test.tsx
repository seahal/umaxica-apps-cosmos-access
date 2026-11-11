import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { patch: vi.fn(), post: vi.fn(), delete: vi.fn() },
  usePage: () => ({ props: { errors: { base: "コードが正しくありません" } } }),
  useForm: (initial: Record<string, unknown>) => ({
    data: initial,
    setData: vi.fn(),
    errors: { pass_code: "コードが正しくありません" },
    processing: false,
    post: vi.fn(),
    patch: vi.fn(),
  }),
}));

const { default: MfaChallengeChoice } = await import("@/features/auth/MfaChallengeChoice");
const { default: OtpVerificationForm } = await import("@/features/auth/signup/OtpVerificationForm");

describe("MfaChallengeChoice", () => {
  it("offers the factor held by the actor", () => {
    const markup = renderToStaticMarkup(
      <MfaChallengeChoice
        title="二段階認証"
        description="続けます。"
        methods={[{ key: "passkey", label: "パスキー", href: "/sign/in/challenge/passkey/new" }]}
        no_methods_notice={null}
        cancel={{ label: "キャンセル", action: "/sign/in/challenge", method: "delete" }}
      />,
    );

    expect(markup).toContain('href="/sign/in/challenge/passkey/new"');
  });

  it("leaves cancellation as the only exit when no factor is available", () => {
    const markup = renderToStaticMarkup(
      <MfaChallengeChoice
        title="二段階認証"
        description="続けます。"
        methods={[]}
        no_methods_notice="利用できる方法がありません"
        cancel={{ label: "キャンセル", action: "/sign/in/challenge", method: "delete" }}
      />,
    );

    expect(markup).toContain("利用できる方法がありません");
    expect(markup).not.toContain("<a ");
    expect(markup).toMatch(/<form[^>]*action="\/sign\/in\/challenge" method="post"/u);
    expect(markup).toContain('name="_method" value="delete"');
  });
});

it("renders the OTP form, resend action, and cancellation supplied by Auth", () => {
  const markup = renderToStaticMarkup(
    <OtpVerificationForm
      title="確認コード入力"
      description="コードを送りました。"
      action="/sign/up/check/email/otp?fb=flow-binding"
      scope="client_email"
      code_label="確認コード"
      code_placeholder="123456"
      submit_label="確認"
      delivery_help="届かない場合"
      error_heading={null}
      errors={[]}
      otp_resend={{
        endpoint: "/sign/up/check/email/otp?fb=flow-binding",
        state: "flow-binding",
        messages: {
          button_label: "再送信",
          sent_message: "送信しました",
          too_soon_message: "しばらく待ってください",
          failed_message: "失敗しました",
        },
      }}
      cancel={{
        label: "キャンセル",
        action: "/sign/up/check/email/otp?fb=flow-binding",
        method: "delete",
      }}
    />,
  );

  expect(markup).toContain('name="client_email[pass_code]"');
  expect(markup).toContain("再送信");
  expect(markup).toContain("届かない場合");
});
