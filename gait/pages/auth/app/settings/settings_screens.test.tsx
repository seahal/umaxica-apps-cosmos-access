import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// The screens are pure props renderers, so static markup is enough to prove that what the server
// resolved - the copy, the URLs and the rows - is what the page shows. Handlers are exercised in
// settings_screens_interaction.test.tsx.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { delete: vi.fn(), patch: vi.fn(), post: vi.fn() },
  useForm: (initial: Record<string, string>) => ({
    data: initial,
    setData: vi.fn(),
    transform: vi.fn(),
    patch: vi.fn(),
    post: vi.fn(),
    processing: false,
    errors: {},
  }),
  usePage: () => ({ props: {} }),
}));

const { default: SocialLinkStatus } = await import("@/features/auth/settings/SocialLinkStatus");
const { default: SocialLinkManage } = await import("@/features/auth/settings/SocialLinkManage");
const { default: PasskeysNew } =
  await import("@/pages/auth/app/verification/registration/passkeys/new");
const { default: TotpsNew } = await import("@/pages/auth/app/settings/totps/new");

const turnstile = {
  site_key: "site-key",
  mode: "execute" as const,
  action: null,
  cdata: null,
};

describe("social link screens", () => {
  const shared = {
    title: "Apple",
    heading: "Apple",
    description: "Appleアカウントとの連携",
    back_link: { label: "もどる", href: "/settings" },
  };

  it("shows the link status and the way to change it", () => {
    const html = renderToStaticMarkup(
      <SocialLinkStatus
        {...shared}
        status="連携済み"
        edit_link={{ label: "編集", href: "/settings/apple/edit?ri=jp" }}
      />,
    );

    expect(html).toContain("連携済み");
    expect(html).toContain('href="/settings/apple/edit?ri=jp"');
    expect(html).toContain('href="/settings"');
  });

  it("offers a disconnect form with a challenge while another method remains", () => {
    const html = renderToStaticMarkup(
      <SocialLinkManage
        {...shared}
        unlink={{
          action: "/settings/apple?ri=jp",
          submit_label: "連携解除",
          allowed: true,
          blocked_notice: null,
        }}
        connect={null}
        turnstile={turnstile}
      />,
    );

    expect(html).toMatch(/<button[^>]*type="submit"[^>]*>連携解除<\/button>/u);
    expect(html).toContain('name="cf-turnstile-response"');
    // Not `.not.toContain("disabled")`: the button's own Tailwind classes name a `disabled:`
    // variant regardless of state. What must be absent is the actual disabled attribute.
    expect(html).not.toMatch(/\bdisabled(=|\s|>)/u);
  });

  it("disables the disconnect form and explains why when it is the last method", () => {
    const html = renderToStaticMarkup(
      <SocialLinkManage
        {...shared}
        unlink={{
          action: "/settings/apple?ri=jp",
          submit_label: "連携解除",
          allowed: false,
          blocked_notice: "他のログイン方法がありません",
        }}
        connect={null}
        turnstile={null}
      />,
    );

    expect(html).toContain("disabled");
    expect(html).toContain("他のログイン方法がありません");
    expect(html).not.toContain('name="cf-turnstile-response"');
  });

  it("offers a document POST to connect while the provider is unlinked", () => {
    const html = renderToStaticMarkup(
      <SocialLinkManage
        {...shared}
        unlink={null}
        connect={{ action: "/settings/apple?ri=jp", label: "連携する" }}
        turnstile={null}
      />,
    );

    expect(html).toContain('method="post"');
    expect(html).toContain('name="authenticity_token"');
    // The submit control carries the label. Whether it is an `<input type="submit">` or a
    // `<button type="submit">` is presentation; what matters is that the form submits under it.
    expect(html).toMatch(/type="submit"[^>]*>連携する<|value="連携する"/u);
  });
});

describe("passkey settings screens", () => {
  it("frames the registration ceremony", () => {
    const html = renderToStaticMarkup(
      <PasskeysNew
        title="Passkeyを追加"
        description="認証器を登録します"
        panel={{
          options_url: "/settings/passkeys/options",
          verification_url: "/settings/passkeys/verification",
          turnstile_site_key: "site-key",
          turnstile_error_message: "検証に失敗しました",
          description_label: "名前",
          description_placeholder: "MacBook",
          submit_label: "登録",
        }}
        cancel={{ label: "キャンセル", action: "/settings/passkeys", method: "post" }}
      />,
    );

    expect(html).toContain("Passkeyを追加");
    expect(html).toContain("登録");
    expect(html).toContain('placeholder="MacBook"');
  });
});

describe("totp settings screens", () => {
  it("shows the provisioning code and the enrolment form", () => {
    const html = renderToStaticMarkup(
      <TotpsNew
        title="認証アプリを追加"
        description="認証アプリを登録します"
        back_link={{ label: "もどる", href: "/settings/totps?ri=jp" }}
        start={null}
        qr_code_image="data:image/png;base64,AAAA"
        qr_fallback="QRコードを読み取れない場合"
        form={{
          action: "/settings/totps?ri=jp",
          scope: "user_totp_credential",
          title_label: "名前",
          title_placeholder: "iPhone",
          title_hint: "わかりやすい名前",
          title: null,
          enrollment_id: "enrollment-1",
          first_token_label: "確認コード",
          first_token_placeholder: "123456",
          first_token_help: "アプリに表示されるコード",
          first_token_delivery_help: "コードはアプリに表示されます",
          submit_label: "登録",
        }}
        cancel={{
          label: "キャンセル",
          action: "/settings/totps/enrollment?ri=jp",
          method: "delete",
        }}
        turnstile={turnstile}
        error_header={null}
        error_messages={[]}
      />,
    );

    expect(html).toContain('src="data:image/png;base64,AAAA"');
    expect(html).toContain("QRコードを読み取れない場合");
    expect(html).toContain('name="cf-turnstile-response"');
    expect(html).toMatch(/type="submit"[^>]*>登録<|value="登録"/u);
  });

  // Without an active enrolment the page only offers the explicit POST that starts one: no QR code,
  // no secret, no cancellation.
  it("offers only the enrolment start when no enrolment is active", () => {
    const html = renderToStaticMarkup(
      <TotpsNew
        title="認証アプリを追加"
        description="認証アプリを登録します"
        back_link={{ label: "もどる", href: "/settings/totps?ri=jp" }}
        start={{ action: "/settings/totps/enrollment?ri=jp", label: "認証アプリを追加" }}
        qr_code_image={null}
        qr_fallback="QRコードを読み取れない場合"
        form={{
          action: "/settings/totps?ri=jp",
          scope: "user_totp_credential",
          title_label: "名前",
          title_placeholder: "iPhone",
          title_hint: "わかりやすい名前",
          title: null,
          enrollment_id: null,
          first_token_label: "確認コード",
          first_token_placeholder: "123456",
          first_token_help: "アプリに表示されるコード",
          first_token_delivery_help: "コードはアプリに表示されます",
          submit_label: "登録",
        }}
        cancel={null}
        turnstile={turnstile}
        error_header={null}
        error_messages={[]}
      />,
    );

    expect(html).toMatch(/<form[^>]*action="\/settings\/totps\/enrollment\?ri=jp" method="post"/u);
    expect(html).not.toContain("data:image/png");
    expect(html).not.toContain('name="_method"');
  });

  it("cancels an active enrolment with a DELETE form, not a link", () => {
    const html = renderToStaticMarkup(
      <TotpsNew
        title="認証アプリを追加"
        description="認証アプリを登録します"
        back_link={{ label: "もどる", href: "/settings/totps?ri=jp" }}
        start={null}
        qr_code_image="data:image/png;base64,AAAA"
        qr_fallback="QRコードを読み取れない場合"
        form={{
          action: "/settings/totps?ri=jp",
          scope: "user_totp_credential",
          title_label: "名前",
          title_placeholder: "iPhone",
          title_hint: "わかりやすい名前",
          title: null,
          enrollment_id: "enrollment-1",
          first_token_label: "確認コード",
          first_token_placeholder: "123456",
          first_token_help: "アプリに表示されるコード",
          first_token_delivery_help: "コードはアプリに表示されます",
          submit_label: "登録",
        }}
        cancel={{
          label: "キャンセル",
          action: "/settings/totps/enrollment?ri=jp",
          method: "delete",
        }}
        turnstile={turnstile}
        error_header={null}
        error_messages={[]}
      />,
    );

    expect(html).toMatch(/<form[^>]*action="\/settings\/totps\/enrollment\?ri=jp" method="post"/u);
    expect(html).toContain('name="_method" value="delete"');
    expect(html).not.toContain('href="/settings/totps/enrollment');
  });

  it("repeats the enrolment errors the server produced", () => {
    const html = renderToStaticMarkup(
      <TotpsNew
        title="認証アプリを追加"
        description="認証アプリを登録します"
        back_link={{ label: "もどる", href: "/settings/totps?ri=jp" }}
        start={null}
        qr_code_image="data:image/png;base64,AAAA"
        qr_fallback="QRコードを読み取れない場合"
        form={{
          action: "/settings/totps?ri=jp",
          scope: "user_totp_credential",
          title_label: "名前",
          title_placeholder: "iPhone",
          title_hint: "わかりやすい名前",
          title: "iPhone",
          enrollment_id: "enrollment-1",
          first_token_label: "確認コード",
          first_token_placeholder: "123456",
          first_token_help: "アプリに表示されるコード",
          first_token_delivery_help: "コードはアプリに表示されます",
          submit_label: "登録",
        }}
        cancel={{
          label: "キャンセル",
          action: "/settings/totps/enrollment?ri=jp",
          method: "delete",
        }}
        turnstile={turnstile}
        error_header="1件のエラー"
        error_messages={["確認コードが正しくありません"]}
      />,
    );

    expect(html).toContain("1件のエラー");
    expect(html).toContain("確認コードが正しくありません");
  });
});
