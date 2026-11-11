import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, describe, expect, it, vi } from "vitest";

import { present } from "../../../../support/present";

// These tests mount the screens and dispatch real DOM events, which is the only way to reach the
// submit and confirm branches: the destructive actions must keep their verb and their confirmation.
const post = vi.fn();
const deleteRequest = vi.fn();
const transform = vi.fn<(callback: (data: Record<string, string>) => unknown) => void>();
const setData = vi.fn();

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { delete: deleteRequest, post },
  useForm: (initial: Record<string, string>) => ({
    data: initial,
    setData,
    transform,
    post,
    processing: false,
    errors: {},
  }),
  usePage: () => ({ props: {} }),
}));

const { default: SocialLinkManage } = await import("@/features/auth/settings/SocialLinkManage");
const { default: TotpsNew } = await import("@/pages/auth/app/settings/totps/new");

let container: HTMLDivElement;
let root: Root;

const mount = (element: React.ReactElement) => {
  container = document.createElement("div");
  document.body.append(container);
  root = createRoot(container);
  act(() => {
    root.render(element);
  });
};

const submitForm = () => {
  const form = container.querySelector<HTMLFormElement>("form")!;
  act(() => {
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });
};

// React tracks the last value it wrote to a controlled input, so a plain assignment is ignored.
// Writing through the native setter is what makes the change event reach the handler.
const typeInto = (input: HTMLInputElement, value: string) => {
  const descriptor = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value");
  act(() => {
    descriptor?.set?.call(input, value);
    input.dispatchEvent(new Event("input", { bubbles: true }));
  });
};

const turnstile = {
  site_key: "site-key",
  mode: "execute" as const,
  action: null,
  cdata: null,
};

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
  vi.unstubAllGlobals();
  post.mockClear();
  deleteRequest.mockClear();
  transform.mockClear();
  setData.mockClear();
});

describe("SocialLinkManage interaction", () => {
  const props = {
    title: "Apple",
    heading: "Apple",
    description: "Appleアカウントとの連携",
    back_link: { label: "もどる", href: "/settings" },
    connect: null,
    turnstile,
  };

  it("disconnects with a DELETE carrying the challenge field", () => {
    mount(
      <SocialLinkManage
        {...props}
        unlink={{
          action: "/settings/apple?ri=jp",
          submit_label: "連携解除",
          allowed: true,
          blocked_notice: null,
        }}
      />,
    );

    submitForm();

    expect(deleteRequest).toHaveBeenCalledWith("/settings/apple?ri=jp", {
      data: { "cf-turnstile-response": "" },
    });
  });

  it("submits nothing while unlinking is not allowed", () => {
    mount(
      <SocialLinkManage
        {...props}
        unlink={{
          action: "/settings/apple?ri=jp",
          submit_label: "連携解除",
          allowed: false,
          blocked_notice: "他のログイン方法がありません",
        }}
      />,
    );

    submitForm();

    expect(deleteRequest).not.toHaveBeenCalled();
  });
});

describe("totp settings interaction", () => {
  it("posts the enrolment under the scope the server named", () => {
    mount(
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

    const inputs = [...container.querySelectorAll<HTMLInputElement>("input[type=text]")];
    typeInto(present(inputs[0], "the title field"), "iPhone");
    typeInto(present(inputs[1], "the first token field"), "123456");

    expect(setData).toHaveBeenCalledWith("title", "iPhone");
    expect(setData).toHaveBeenCalledWith("first_token", "123456");

    submitForm();

    expect(transform).toHaveBeenCalled();
    const totpNewTransformer = present(transform.mock.calls[0]?.[0], "a transform callback");
    expect(totpNewTransformer({ title: "iPhone", first_token: "123456" })).toEqual({
      user_totp_credential: {
        title: "iPhone",
        first_token: "123456",
        enrollment_id: "enrollment-1",
      },
      "cf-turnstile-response": "",
    });
    expect(post).toHaveBeenCalledWith("/settings/totps?ri=jp");
  });
});
