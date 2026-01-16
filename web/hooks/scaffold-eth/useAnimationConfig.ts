import { useEffect, useRef, useState } from "react";

const ANIMATION_TIME = 2000;

export function useAnimationConfig(data: any) {
  const [showAnimation, setShowAnimation] = useState(false);
  const prevDataRef = useRef<any>(undefined);

  useEffect(() => {
    if (prevDataRef.current !== undefined && prevDataRef.current !== data) {
      setShowAnimation(true);
      setTimeout(() => setShowAnimation(false), ANIMATION_TIME);
    }
    prevDataRef.current = data;
  }, [data]);

  return {
    showAnimation,
  };
}
