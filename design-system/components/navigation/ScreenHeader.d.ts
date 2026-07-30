export interface ScreenHeaderProps {
  /** Sentence case, 28px/400 */
  title: string;
  /** Mono context line above, e.g. 'MON 07.28 · WK 31' */
  context?: string;
  /** Right-aligned mono meta, e.g. 'D-028' */
  meta?: string;
  /** Quiet trailing action text */
  trailing?: React.ReactNode;
}
export declare function ScreenHeader(props: ScreenHeaderProps): JSX.Element;
