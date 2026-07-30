export interface AttentionBannerProps {
  /** Rule color family; state is carried by the title text first */
  zone?: 'optimal' | 'caution' | 'danger' | 'low' | 'accent';
  title: string;
  message?: string;
  action?: string;
  onAction?: () => void;
  onDismiss?: () => void;
}
export declare function AttentionBanner(props: AttentionBannerProps): JSX.Element;
